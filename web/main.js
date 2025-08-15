// CHIP-8 key mapping (hex key -> button index)
const KEY_MAP = {
  1: 0x1,
  2: 0x2,
  3: 0x3,
  C: 0xc,
  4: 0x4,
  5: 0x5,
  6: 0x6,
  D: 0xd,
  7: 0x7,
  8: 0x8,
  9: 0x9,
  E: 0xe,
  A: 0xa,
  0: 0x0,
  B: 0xb,
  F: 0xf,
};

// Keyboard mapping for desktop
const KEYBOARD_MAP = {
  1: 0x1,
  2: 0x2,
  3: 0x3,
  4: 0xc,
  q: 0x4,
  w: 0x5,
  e: 0x6,
  r: 0xd,
  a: 0x7,
  s: 0x8,
  d: 0x9,
  f: 0xe,
  z: 0xa,
  x: 0x0,
  c: 0xb,
  v: 0xf,
};

class CHIP8Emulator {
  constructor() {
    this.wasm = null;
    this.canvas = document.getElementById("screen");
    this.ctx = this.canvas.getContext("2d");
    this.running = false;
    this.frameRate = 60; // 60 FPS

    this.setupCanvas();
    this.setupButtons();
    this.setupKeyboard();
    this.addRomLoader();
    this.init();
  }

  async init() {
    try {
      // Load the WASM module
      const wasmModule = await WebAssembly.instantiateStreaming(
        fetch("./chip8.wasm"),
        {
          env: {
            // Add any imports your WASM module might need
          },
        },
      );

      this.wasm = wasmModule.instance.exports;

      console.log("Available WASM exports:", Object.keys(this.wasm));

      // Check if we have the required functions
      const requiredFunctions = [
        "init",
        "load_rom",
        "tick",
        "get_display",
        "key_down",
        "key_up",
      ];
      const missingFunctions = requiredFunctions.filter(
        (fn) => typeof this.wasm[fn] !== "function",
      );

      if (missingFunctions.length > 0) {
        console.error("Missing WASM functions:", missingFunctions);
        alert(
          `WASM compilation issue detected!\n\nMissing functions: ${
            missingFunctions.join(", ")
          }\n\nOnly found exports: ${
            Object.keys(this.wasm).join(", ")
          }\n\nPlease check your Zig compilation. You might need to:\n
1. Use 'export' keyword properly\n
2. Check your build.zig file\n
3. Ensure you're targeting WASM correctly`,
        );
        return;
      }

      // Initialize the CHIP-8 CPU
      this.wasm.init();

      console.log("CHIP-8 emulator initialized successfully");

      // Start the emulation loop
      this.startEmulation();
    } catch (error) {
      console.error("Failed to initialize WASM module:", error);

      // Try alternative loading method
      try {
        console.log("Trying alternative WASM loading method...");
        const response = await fetch("./chip8.wasm");
        const bytes = await response.arrayBuffer();
        const wasmModule = await WebAssembly.instantiate(bytes, {
          env: {},
        });

        this.wasm = wasmModule.instance.exports;
        console.log(
          "Available WASM exports (alternative method):",
          Object.keys(this.wasm),
        );

        const requiredFunctions = [
          "init",
          "load_rom",
          "tick",
          "get_display",
          "key_down",
          "key_up",
        ];
        const missingFunctions = requiredFunctions.filter(
          (fn) => typeof this.wasm[fn] !== "function",
        );

        if (missingFunctions.length > 0) {
          throw new Error(
            `Missing functions: ${missingFunctions.join(", ")}`,
          );
        }

        this.wasm.init();
        console.log(
          "CHIP-8 emulator initialized successfully (alternative method)",
        );
        this.startEmulation();
      } catch (altError) {
        console.error("Alternative loading also failed:", altError);
        alert(
          "WASM module loading failed. Please check the compilation process and ensure all functions are properly exported.",
        );
      }
    }
  }

  setupCanvas() {
    // Set up canvas for pixel-perfect rendering
    this.ctx.imageSmoothingEnabled = false;
    this.ctx.msImageSmoothingEnabled = false;
    this.ctx.webkitImageSmoothingEnabled = false;
    this.ctx.mozImageSmoothingEnabled = false;

    // Clear the canvas initially
    this.ctx.fillStyle = "#ffff";
    this.ctx.fillRect(0, 0, 64, 32);
  }

  setupButtons() {
    const buttons = document.querySelectorAll("button[data-key]");

    buttons.forEach((button) => {
      const key = button.dataset.key;
      const keyCode = KEY_MAP[key];

      // Touch/mouse events
      button.addEventListener("touchstart", (e) => {
        e.preventDefault();
        this.keyDown(keyCode);
      });

      button.addEventListener("mousedown", (e) => {
        e.preventDefault();
        this.keyDown(keyCode);
      });

      button.addEventListener("touchend", (e) => {
        e.preventDefault();
        this.keyUp(keyCode);
      });

      button.addEventListener("mouseup", (e) => {
        e.preventDefault();
        this.keyUp(keyCode);
      });

      button.addEventListener("mouseleave", () => {
        this.keyUp(keyCode);
      });
    });
  }

  setupKeyboard() {
    document.addEventListener("keydown", (e) => {
      const key = e.key.toLowerCase();
      if (KEYBOARD_MAP.hasOwnProperty(key)) {
        e.preventDefault();
        this.keyDown(KEYBOARD_MAP[key]);
      }
    });

    document.addEventListener("keyup", (e) => {
      const key = e.key.toLowerCase();
      if (KEYBOARD_MAP.hasOwnProperty(key)) {
        e.preventDefault();
        this.keyUp(KEYBOARD_MAP[key]);
      }
    });
  }

  addRomLoader() {
    // Create file input for ROM loading
    const fileInput = document.createElement("input");
    fileInput.type = "file";
    fileInput.accept = ".ch8,.rom";
    fileInput.style.display = "none";
    document.body.appendChild(fileInput);

    // Create load ROM button
    const loadButton = document.createElement("button");
    loadButton.textContent = "Load ROM";
    loadButton.style.position = "absolute";
    loadButton.style.top = "10px";
    loadButton.style.right = "10px";
    loadButton.style.padding = "10px 20px";
    loadButton.style.fontSize = "1rem";
    loadButton.style.background = "#333";
    loadButton.style.color = "white";
    loadButton.style.border = "1px solid #555";
    loadButton.style.borderRadius = "6px";
    loadButton.style.cursor = "pointer";

    loadButton.addEventListener("click", () => {
      fileInput.click();
    });

    fileInput.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (file) {
        this.loadROM(file);
      }
    });

    document.body.appendChild(loadButton);

    // Add instruction text
    const instructions = document.createElement("div");
    instructions.innerHTML = `
<div style="position: absolute; top: 10px; left: 10px; font-size: 0.9rem; color: #ccc;">
  <div>Keyboard: 1234 QWER ASDF ZXCV</div>
  <div>Load a CHIP-8 ROM file to start playing</div>
</div>
`;
    document.body.appendChild(instructions);
  }

  async loadROM(file) {
    try {
      const arrayBuffer = await file.arrayBuffer();
      const rom = new Uint8Array(arrayBuffer);

      if (!this.wasm) {
        throw new Error("WASM module not loaded");
      }

      console.log(`Loading ROM: ${file.name} (${rom.length} bytes)`);

      // Check if we have the required functions
      if (typeof this.wasm.load_rom !== "function") {
        throw new Error("load_rom function not found in WASM exports");
      }

      // For Zig WASM, we need to pass the data differently
      // Create a buffer in WASM memory
      const wasmMemory = new Uint8Array(this.wasm.memory.buffer);

      // Find a safe place to put the ROM data (after the WASM's own data)
      const romOffset = 0x10000; // Use a high offset to avoid conflicts

      // Make sure we have enough memory
      if (romOffset + rom.length > wasmMemory.length) {
        throw new Error("ROM too large for available memory");
      }

      // Copy ROM data to WASM memory
      wasmMemory.set(rom, romOffset);

      // Reset the emulator first
      if (typeof this.wasm.init === "function") {
        this.wasm.init();
      }

      // Load the ROM into the emulator
      this.wasm.load_rom(romOffset, rom.length);
      this.stopEmulation();
      this.startEmulation();

      console.log(`ROM loaded successfully: ${file.name}`);
    } catch (error) {
      console.error("Failed to load ROM:", error);
      alert("Failed to load ROM file: " + error.message);
    }
  }

  keyDown(keyCode) {
    if (this.wasm && typeof this.wasm.key_down === "function") {
      this.wasm.key_down(keyCode);
    }
  }

  keyUp(keyCode) {
    if (this.wasm && typeof this.wasm.key_up === "function") {
      this.wasm.key_up(keyCode);
    }
  }

  startEmulation() {
    if (this.running) return;

    this.running = true;
    const frameTime = 1000 / this.frameRate;

    const gameLoop = () => {
      if (!this.running) return;

      try {
        // Execute several CPU cycles per frame (CHIP-8 typically runs at ~500-1000 Hz)
        const cyclesPerFrame = 10;
        for (let i = 0; i < cyclesPerFrame; i++) {
          if (this.wasm && typeof this.wasm.tick === "function") {
            this.wasm.tick();
          }
        }

        // Update display
        this.updateDisplay();
      } catch (error) {
        console.error("Error in game loop:", error);
        this.stopEmulation();
        return;
      }

      setTimeout(gameLoop, frameTime);
    };

    gameLoop();
  }

  stopEmulation() {
    this.running = false;
  }

  updateDisplay() {
    if (!this.wasm || typeof this.wasm.get_display !== "function") return;

    try {
      // Get display data from WASM
      const displayPtr = this.wasm.get_display();

      // Check if we got a valid pointer
      if (displayPtr === 0 || displayPtr === undefined) {
        console.warn("Invalid display pointer received");
        return;
      }

      const displayData = new Uint8Array(
        this.wasm.memory.buffer,
        displayPtr,
        64 * 32,
      );

      // Clear the canvas
      this.ctx.fillStyle = "#000000";
      this.ctx.fillRect(0, 0, 64, 32);

      // Draw white pixels for each "on" pixel
      this.ctx.fillStyle = "#FFFFFF";

      for (let y = 0; y < 32; y++) {
        for (let x = 0; x < 64; x++) {
          const pixelIndex = y * 64 + x;
          if (displayData[pixelIndex] === 1) {
            this.ctx.fillRect(x, y, 1, 1);
          }
        }
      }
    } catch (error) {
      console.error("Error updating display:", error);

      // Fallback: just clear the screen on error
      this.ctx.fillStyle = "#000000";
      this.ctx.fillRect(0, 0, 64, 32);
    }
  }
}

// Initialize the emulator when the page loads
document.addEventListener("DOMContentLoaded", () => {
  new CHIP8Emulator();
});
