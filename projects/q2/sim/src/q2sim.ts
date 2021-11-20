// Simulator for the Q2 12-bit discrete transistor computer.

import { LCD_FONT } from "./lcd-font";
import { Example, EXAMPLES } from "./examples"

const REG_X = 45;
const AREG_Y = 63;
const XREG_Y = 158;
const PREG_Y = 330;
const SREG_Y = 493;
const REG_SPACING = 49.25;
const BIT_WIDTH = 7;
const BIT_HEIGHT = 5;
const LCD_X = 445;
const LCD_Y = 828;
const LCD_WIDTH = (16 * 6 + 1) * 2.4;
const LCD_HEIGHT = (2 * 9 + 1) * 3;

class LCD {
  private offsetx: number;
  private offsety: number;
  private width: number;
  private height: number;
  private content: number[] = new Array<number>(40 * 2);
  private glyphs: number[][] = new Array<Array<number>>(8);
  private cursor: number = 0;
  private glyph_mode: boolean = false;
  private updated: boolean = true;

  constructor(x: number, y: number, width: number, height: number) {
    this.offsetx = x;
    this.offsety = y;
    this.width = width;
    this.height = height;
    for (let i = 0; i < 40 * 2; i++) {
      this.content[i] = 32;
    }
    for (let i = 0; i < 8; i++) {
      this.glyphs[i] = [0, 0, 0, 0, 0];
    }
  }

  render(context): void {
    if(this.updated) {
      const pixel_width = this.width / (16 * 6 + 1);
      const pixel_height = this.height / (2 * 9 + 1);
      context.fillStyle = '#DDD';
      context.fillRect(this.offsetx, this.offsety, this.width, this.height);
      for(let y = 0; y < 2; y++) {
        for(let x = 0; x < 16; x++) {
          const ch = this.content[y * 64 + x];
          const glyph = ch >= 16 ? LCD_FONT[ch - 16] : this.glyphs[ch & 7];
          for(let gy = 0; gy < 8; gy++) {
            for(let gx = 0; gx < 5; gx++) {
              const bit = (glyph[gx] >> (7 - gy)) & 1;
              context.fillStyle = bit ? '#232' : '#EEE';
              context.fillRect(
                this.offsetx + (1 + gx + x * 6) * pixel_width,
                this.offsety + (1 + gy + y * 9) * pixel_height,
                pixel_width,
                pixel_height
              );
            }
          }
        }
      }
      this.updated = false;
    }
  }

  private write_data(d): void {
    if(this.glyph_mode) {
      const mask = 1 << (7 - (this.cursor & 7));
      const glyph_index = this.cursor >> 3;
      for(let i = 0; i < 5; i++) {
        if(d & (1 << (4 - i))) {
          this.glyphs[glyph_index][i] |= mask;
        } else {
          this.glyphs[glyph_index][i] &= ~mask;
        }
      }
      this.cursor = (this.cursor + 1) & 0x3F;
    } else {
      this.content[this.cursor] = d;
      this.cursor = (this.cursor + 1) & 0x7F;
    }
    this.updated = true;
  }

  private write_cmd(c): void {
    if(c & 0x80) {
      // Set RAM address
      this.cursor = c & 0x7F;
      this.glyph_mode = false;
    } else if(c & 0x40) {
      // Set CGRAM address
      this.cursor = c & 0x3F;
      this.glyph_mode = true;
    } else if (c & 1) {
      // Clear screen.
      for(let i = 0; i < 40 * 2; i++) {
        this.content[i] = 32;
      }
      this.cursor = 0;
      this.glyph_mode = false;
    }
    this.updated = true;
  }

  write(d): void {
    if (d & 0x100) {
      this.write_cmd(d & 0xFF);
    } else {
      this.write_data(d & 0xFF);
    }
  }

}

class Bit {
  private x: number;
  private y: number;
  private value: number = 0;
  private output: number = 0;
  private last_output: number = -1;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }

  render(context): void {
    if(this.output !== this.last_output) {
      context.fillStyle = this.output ? '#FF1' : '#555'
      context.fillRect(this.x, this.y, BIT_WIDTH, BIT_HEIGHT);
      this.last_output = this.output;
    }
    this.output = this.value;
  }

  set(v: number): void {
    this.value = v;
    this.output |= v;
  }

  get(): number {
    return this.value;
  }
}

class Bits {
  private bits: Array<Bit>;
  private value: number = 0;

  constructor(bits) {
    this.bits = bits;
  }

  render(context): void {
    for(let i = 0; i < this.bits.length; i++) {
      this.bits[i].render(context);
    }
  }

  get(): number {
    return this.value;
  }

  set(v: number): void {
    if(v !== this.value) {
      this.value = v;
      for(let i = 0; i < this.bits.length; i++) {
        this.bits[i].set((v >> (this.bits.length - 1 - i)) & 1);
      }
    }
  }
}

class Register extends Bits {
  constructor(x: number, y: number, n: number = 12) {
    const bits = new Array<Bit>(n);
    for(let i = 0; i < n; i++) {
      bits[i] = new Bit(x + i * REG_SPACING, y);
    }
    super(bits);
  }
}

class Bus extends Bits {
  constructor(y: number) {
    const offsetx = 43;
    const bits = new Array<Bit>(12);
    for(let i = 0; i < 12; i++) {
      const x = i * 17 + ((i >= 8) ? 12 : (i >= 4) ? 6 : 0);
      bits[i] = new Bit(offsetx + x, y);
    }
    super(bits);
  }
}

abstract class Input {
  protected x: number;
  protected y: number;
  protected width: number;
  protected height: number;

  constructor(
    x: number,
    y: number,
    width: number,
    height: number
  ) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }

  clicked(mx: number, my: number): boolean {
    return mx >= this.x && mx <= this.x + this.width
      && my >= this.y && my <= this.y + this.height;
  }

  render(context): void {
    context.strokeStyle = '#F00';
    context.lineWidth = 1;
    context.lineCap = 'butt';
    context.strokeRect(
      this.x,
      this.y,
      this.width,
      this.height
    );
  }

  protected abstract run(cpu: CPU): void;

  process(cpu: CPU, mx: number, my: number): boolean {
    if(this.clicked(mx, my)) {
      this.run(cpu);
      return true;
    }
    return false;
  }
}

class Button extends Input {
  private action: (cpu: CPU) => void;

  constructor(
    x: number,
    y: number,
    action: (cpu: CPU) => void
  ) {
    super(x, y, 25, 25);
    this.action = action;
  }

  protected run(cpu: CPU): void {
    (this.action)(cpu);
  }
}

class Key extends Input {
  mask: number;

  constructor(x: number, y: number, mask: number) {
    super(x, y, 25, 25);
    this.mask = mask;
  }

  protected run(cpu: CPU): void {
  }
}

class Switch extends Input {
  private value: boolean = false;

  constructor(
    x: number,
    y: number,
    width: number,
    height: number
  ) {
    super(x, y, width, height);
  }

  get(): boolean {
    return this.value;
  }

  set(v: boolean): void {
    this.value = v;
  }

  protected run(cpu: CPU): void {
    this.value = !this.value;
  }

  render(context): void {
    context.fillStyle = this.value ? '#0F0' : '#000';
    context.fillRect(this.x, this.y, this.width, this.height);
    super.render(context);
  }
}

class SwitchRegister {
  switches: Array<Switch> = new Array<Switch>(12);

  constructor() {
    const y = 936;
    const offsetx = 43;
    for(let i = 0; i < 12; i++) {
      const x = i * 17 + ((i >= 8) ? 12 : (i >= 4) ? 6 : 0);
      this.switches[i] = new Switch(offsetx + x, y, 10, 28);
    }
  }

  get(): number {
    let result = 0;
    for(let i = 0; i < 12; i++) {
      result = (result << 1) | (this.switches[i].get() ? 1 : 0);
    }
    return result;
  }

  reset(): void {
    for(let s of this.switches) {
      s.set(false);
    }
  }

  render(context): void {
    for(let i = 0; i < 12; i++) {
      this.switches[i].render(context);
    }
  }
}

class Memory {
  private ram: Array<number> = new Array<number>(8192);
  private lcd: LCD = new LCD(LCD_X, LCD_Y, LCD_WIDTH, LCD_HEIGHT);
  private abus: Bus = new Bus(910);
  private dbus: Bus = new Bus(922);
  private scl: Bit = new Bit(REG_X + 10 * REG_SPACING, SREG_Y);
  private sda: Bit = new Bit(REG_X + 11 * REG_SPACING, SREG_Y);
  private key_mask: number;
  private keys: Array<Key>;
  private data_field: Bit = new Bit(548, 644);
  private instruction_field: Bit = new Bit(594, 644);

  constructor() {
    this.keys = [
      new Key(458, 931, 1 << 0),
      new Key(533, 931, 1 << 1),
      new Key(495, 917, 1 << 2),
      new Key(495, 944, 1 << 3),
      new Key(620, 931, 1 << 4),
    ];
    this.reset(0);
  }

  private get_full_addr(addr: number, defer: boolean): number {
      const field = defer ? this.data_field : this.instruction_field;
      return ((field.get() ? 1 : 0) << 12) | addr;
  }

  read(addr: number, defer: boolean): number {
    let result;
    if(addr == 0xFFF) {
      result = 0xC60;
      result |= this.scl.get() << 9;
      result |= this.sda.get() << 8;
      result |= this.key_mask & 0x1F;
    } else {
      const full_addr = this.get_full_addr(addr, defer);
      result = this.ram[full_addr];
    }
    this.abus.set(addr);
    this.dbus.set(result);
    return result;
  }

  write(addr: number, value: number, defer: boolean): void {
    this.abus.set(addr);
    this.dbus.set(value);
    if(addr == 0xFFF) {
      const device = (value >> 10) & 3;
      if(device == 2) {
        // I2C
        this.scl.set(((value >> 9) & 1) ? 0 : 1);
        this.sda.set(((value >> 8) & 1) ? 0 : 1);
      } else if(device == 3) {
        // Data field.
        this.data_field.set(value & 1);
      } else {
        this.lcd.write(value);
      }
    } else {
      const full_addr = this.get_full_addr(addr, defer);
      this.ram[full_addr] = value;
    }
  }

  jump(): void {
    this.instruction_field.set(this.data_field.get());
  }

  render(context): void {
    this.lcd.render(context);
    this.abus.render(context);
    this.dbus.render(context);
    this.data_field.render(context);
    this.instruction_field.render(context);
    this.sda.render(context);
    this.scl.render(context);
    for(let key of this.keys) {
      key.render(context);
    }
  }

  private key_index(event): number {
    switch(event.keyCode) {
      case 65:  // A
      case 37:  // Left
        return 0;
      case 68:  // D
      case 39:  // Right
        return 1;
      case 87:  // W
      case 38:  // Up
        return 2;
      case 83:  // S
      case 40:  // Down
        return 3;
      case 32:  // Space
      case 13:  // Enter
        return 4;
      default: return -1;
    }
  }

  reset(addr: number): void {
    this.read(addr, false);
    this.key_mask = 0x01F;
    this.instruction_field.set(0);
    this.data_field.set(0);
    this.sda.set(1)
    this.scl.set(1)
  }

  press_key(event): void {
    const key = this.key_index(event);
    if(key >= 0) {
      this.key_mask &= ~(1 << key);
    }
  }

  release_key(event): void {
    const key = this.key_index(event);
    if(key >= 0) {
      this.key_mask |= 1 << key;
    }
  }

  press(x: number, y: number): void {
    for(let key of this.keys) {
      if(key.clicked(x, y)) {
        this.key_mask &= ~key.mask;
        break;
      }
    }
  }

  release(x: number, y: number): void {
    this.key_mask = 0x01F;
  }
}

class CPU {
  private areg: Register = new Register(REG_X, AREG_Y, 12);
  private xreg: Register = new Register(REG_X, XREG_Y, 12);
  private preg: Register = new Register(REG_X, PREG_Y, 12);
  private opcode: Register = new Register(REG_X, SREG_Y, 4);
  private flag: Register = new Register(REG_X + 4 * REG_SPACING, SREG_Y, 1);
  private state: Register = new Register(REG_X + 5 * REG_SPACING, SREG_Y, 4);
  private cdiv: Register = new Register(REG_X + 9 * REG_SPACING, SREG_Y, 1);
  private running: Bit = new Bit(360, 919);
  private mem: Memory = new Memory();
  private inputs: Array<Input>;
  private fast: Switch = new Switch(391, 675, 28, 10);
  private switches: SwitchRegister = new SwitchRegister();
  private last_ms: DOMHighResTimeStamp;

  constructor() {
    this.fast.set(true);
    this.inputs = [
      new Button(275, 944, (cpu) => cpu.reset()),
      new Button(312, 944, (cpu) => cpu.stop()),
      new Button(351, 944, (cpu) => cpu.start()),
      new Button(275, 912, (cpu) => cpu.deposit()),
      new Button(312, 912, (cpu) => cpu.incp()),
      this.fast,
    ].concat(this.switches.switches);
  }

  private next_state(): void {
    const next = (this.state.get() + 1) & 15;
    this.state.set(next);
  }

  private fetch(): void {
    const addr = this.preg.get();
    const word = this.mem.read(addr, false);

    // Update opcode.
    this.opcode.set(word >> 8);

    // Update X.
    const xh = (word & 0x080) ? 0x000 : (addr & 0xF80);
    const xl = word & 0x07F;
    this.xreg.set(xh | xl);

    // Update P.
    this.incp();

    // Update state.
    this.next_state();
  }

  private defer(): void {
    if(this.opcode.get() & 1) {
      const addr = this.xreg.get();
      this.xreg.set(this.mem.read(addr, false));
    }
    this.next_state();
  }

  private load(): void {
    if(!(this.opcode.get() & 8)) {
      const defer = (this.opcode.get() & 1) !== 0;
      const addr = this.xreg.get();
      this.xreg.set(this.mem.read(addr, defer));
    }
    this.next_state();
  }

  private setf(v: number): void {
    this.flag.set(v ? 1 : 0);
  }

  private getf(): number {
    return this.flag.get();
  }

  private exec(): void {
    switch(this.opcode.get() >> 1) {
      case 0: // LDA
        this.next_state();
        this.flag.set(1);
        break;
      case 1: // NOR
        this.next_state();
        this.flag.set(1);
        break;
      case 2: // ADD
        this.next_state();
        this.flag.set(0);
        break;
      case 3: // SHR
        this.next_state();
        this.flag.set(this.xreg.get() & 1);
        break;
      case 4: // LEA
        this.next_state();
        break;
      case 5: // STA
        const addr = this.xreg.get();
        const defer = (this.opcode.get() & 1) !== 0;
        this.mem.write(addr, this.areg.get(), defer);
        this.state.set(0);
        break;
      case 6: // JMP
        this.preg.set(this.xreg.get());
        this.state.set(0);
        this.mem.jump();
        break;
      case 7: // JFC
        if(!this.getf()) {
          this.preg.set(this.xreg.get());
          this.mem.jump();
        }
        this.state.set(0);
        break;
    }
  }

  private alu(): void {
    const currenta = this.areg.get();
    const currentx = this.xreg.get();
    const xbit0 = currentx & 1;
    const nextx = currentx >> 1;
    let abit0 = currenta & 1;
    switch((this.opcode.get() >> 1) & 3) {
      case 0: // LDA/LEA
        abit0 = xbit0;
        if(!(this.opcode.get() & 8)) {
          if(abit0) {
            this.flag.set(0);
          }
        }
        break;
      case 1: // NOR
        abit0 = (~(abit0 | xbit0)) & 1;
        if(abit0) {
          this.flag.set(0);
        }
        break;
      case 2: // ADD
        const temp = abit0 + xbit0 + this.flag.get();
        this.flag.set((temp & 2) >> 1);
        abit0 = temp & 1;
        break;
      case 3: // SHR
        const xbit1 = nextx & 1;
        abit0 = xbit1;
        break;
    }
    this.next_state();
    this.areg.set((currenta >> 1) | (abit0 << 11)) 
    this.xreg.set(nextx);
  }

  tick(): void {
    if(this.running.get()) {
      const elapsed_ms = Math.min(
        performance.now() - this.last_ms, 200000
      )
      const cycles = this.fast.get() ? (100 * elapsed_ms) : 1;
      for(let iter = 0; iter < cycles; iter++) {
        if(this.cdiv.get()) {
          switch(this.state.get()) {
            case 0: this.fetch(); break;
            case 1: this.defer(); break;
            case 2: this.load(); break;
            case 3: this.exec(); break;
            default: this.alu(); break;
          }
          this.cdiv.set(0);
        } else {
          this.cdiv.set(1);
        }
      }
    }
    this.last_ms = performance.now();
  }

  write(addr: number, value: number): void {
    this.mem.write(addr, value, false);
  }

  start(): void {
    this.last_ms = performance.now();
    this.running.set(1);
  }

  stop(): void {
    this.running.set(0);
  }

  reset(): void {
    this.stop();
    this.state.set(0);
    this.cdiv.set(0);
    const addr = this.switches.get();
    this.preg.set(addr);
    this.mem.reset(addr);
  }

  load_program(code: string): void {
    this.switches.reset();
    this.reset();
    for(let line of code.split('\n')) {
      if(line) {
        const parts = line.split(':');
        if(parts.length != 2) {
          alert("invalid program");
          break;
        }
        const addr = parseInt('0x' + parts[0]);
        const value = parseInt('0x' + parts[1]);
        cpu.write(addr, value);
      }
    }
  }

  deposit(): void {
    const data = this.switches.get();
    this.mem.write(this.preg.get(), data, false);
  }

  incp(): void {
    const nextp = (this.preg.get() + 1) & 0xFFF;
    this.preg.set(nextp);
    this.mem.read(nextp, false);
  }

  click(x: number, y: number): void {
    for(let input of this.inputs) {
      if(input.process(this, x, y)) {
        break;
      }
    }
  }

  render(context): void {
    this.areg.render(context);
    this.xreg.render(context);
    this.preg.render(context);
    this.state.render(context);
    this.cdiv.render(context);
    this.opcode.render(context);
    this.flag.render(context);
    this.mem.render(context);
    this.running.render(context);
    for(let input of this.inputs) {
      input.render(context);
    }
  }

  press_key(event): void {
    this.mem.press_key(event);
  }

  release_key(event): void {
    this.mem.release_key(event);
  }

  press(x: number, y: number): void {
    this.mem.press(x, y);
  }

  release(x: number, y: number): void {
    this.mem.release(x, y);
  }
}

const canvas: any = document.getElementById("canvas");
const context = canvas.getContext('2d');
const example: any = document.getElementById("example");
const run_button: any = document.getElementById("run-example");
const custom_input: any = document.getElementById("custom");

const cpu = new CPU();
canvas.onclick = function(event) {
  const x = event.offsetX;
  const y = event.offsetY;
  cpu.click(x, y);
};
canvas.onmousedown = (event) => {
  cpu.press(event.offsetX, event.offsetY);
};
canvas.onmouseup = (event) => {
  cpu.release(event.offsetX, event.offsetY);
};
window.onkeydown = (event) => {
  cpu.press_key(event);
};
window.onkeyup = (event) => {
  cpu.release_key(event);
};

function load_example(example: Example, start: boolean) {
  const request = new XMLHttpRequest();
  request.open('GET', 'examples/' + example.path);
  request.send();
  request.onload = (event) => {
    const data = request.responseText;
    cpu.load_program(data);
    if(start) {
      cpu.start();
    }
  };
}

for(let i = 0; i < EXAMPLES.length; i++) {
  const x = EXAMPLES[i];
  const element = document.createElement('option');
  element.value = i.toString();
  element.innerHTML = x.title;
  example.appendChild(element);
}
const custom_element = document.createElement('option');
custom_element.value = EXAMPLES.length.toString();
custom_element.innerHTML = "[no file selected]";
example.appendChild(custom_element);
run_button.onclick = (event) => {
  const selected = example.selectedIndex;
  if(selected < EXAMPLES.length) {
    load_example(EXAMPLES[selected], true);
  } else if(custom_input.files.length > 0) {
    custom_input.files[0].text().then(data => {
      cpu.load_program(data);
      cpu.start();
    });
  }
};
custom_input.onchange = (event) => {
  if(custom_input.files.length > 0) {
    const index = EXAMPLES.length;
    example[index].innerHTML = custom_input.files[0].name;
    example.selectedIndex = index;
  }
};

load_example(EXAMPLES[0], false);

const img = new Image;
img.src = "board.png";
img.onload = function() {
  context.drawImage(this, 0, 0);
  const timer_ms = 50;
  setInterval( () => {
    cpu.tick();
    cpu.render(context);
  }, timer_ms);
}

