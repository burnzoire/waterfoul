require 'waterfoul/instructions/opcode'
require 'waterfoul/instructions/registers'
require 'Waterfoul/instructions/timings'
require 'waterfoul/instructions/jump'
require 'waterfoul/instructions/load'
require 'waterfoul/instructions/logic'
require 'waterfoul/instructions/misc'
require 'waterfoul/instructions/shift'
require 'waterfoul/instructions/prefix'

module Waterfoul
  # These constants represent each state in the F register and are used as a helper to
  # reference the state when setting/resetting a state bit. Any combination of these
  # states can be set at any one time.
  #
  # Z_FLAG: Zero Flag
  # N_FLAG: Subtract Flag
  # H_FLAG: half carry flag
  # C_FLAG: Carry Flag
  # BIT 0-3 Always 0 and not used
  #
  Z_FLAG = 0b1000_0000
  N_FLAG = 0b0100_0000
  H_FLAG = 0b0010_0000
  C_FLAG = 0b0001_0000

  # number of cycles a HALT will puase program execution for
  HALT_CYCLES = 6

  ##
  # The CPU emulates the Sharp LR35902 CPU that is built into the device, similar to the
  # Intel 8080 and Zilog Z80 processor. Each instruction is categorized
  # into a subset of instructions by the type of action performed by the instruction.
  #
  # See lib/instuctions/ for the implementation for the CPU instruction set.
  #
  # I recommend looking at http://www.pastraiser.com/cpu/gameboy/gameboy_opcodes.html for an
  # easy to understand chart for each instruction.
  #
  class CPU
    include Helper
    include Instructions::Opcode
    include Instructions::Timings
    include Instructions::Registers
    include Instructions::Jump
    include Instructions::Load
    include Instructions::Logic
    include Instructions::Misc
    include Instructions::Shift
    include Instructions::Prefix

    # 8 bit registers
    attr_reader :a, :b, :c, :d, :e, :f, :h, :l, :f
    # 8 CPU clock
    attr_reader :m
    # 16 bit registers
    attr_reader :sp, :pc
    # other cpu flags
    attr_reader :ime, :stop

    # init CPU registers to 0
    def initialize(options = {})
      @pc = 0x0000
      @sp = 0x0000
      @a = @b = @c = @d = @e = @f = @h = @l = @f = 0x00
      @m = 0
      @timer = Timer.new
      @ime = false
    end

    # This method emulates the CPU cycle process. Each instruction is
    # fetched from memory (pointed by the program counter) and executed.
    # This processes repeats infinitly until the process is closed
    def step
      reset_tick
      serve_interrupt if @ime
      check_halt if @halt
      if halted?
        @m = 4
      else
        instruction_byte = fetch_instruction
        perform_instruction instruction_byte
      end
      @timer.tick @m
    end

    def check_halt
      @halt = false if @pre_halt_interrupt != $mmu.read_byte(0xFF0F)
    end

    def halted?
      @halt == true
    end

    # Execute the instruction and 
    def perform_instruction(instruction)
      operation = OPCODE[instruction]
      raise 'instruction not found' if operation.nil?
      # perform the instruction
      self.public_send operation
      @m = instruction_cycle_time(instruction) * 4
    end

    # fetch the next byte to be executed from memory and increment the program
    # counter (except under particular circumstances, see interrupts)
    def fetch_instruction(increment_pc = false)
      instruction_byte = $mmu.read_byte @pc
      @pc = (@pc + 1) & 0xFFFF unless increment_pc
      instruction_byte
    end

    private

    # get the number of cycles a instruction takes to execute. The times
    # can be found in the instruction opcode table
    def instruction_cycle_time(instruction)
      if @prefix_cb
        CB_OPCODE_TIMINGS[@prefix_cb]
      elsif @branched
        OPCODE_CONDITIONAL_TIMINGS[instruction]
      else
        OPCODE_TIMINGS[instruction]
      end
    end

    def serve_interrupt
      interrupt = Interrupt.pending_interrupt
      # skip if there is no interrupt to serve
      return if interrupt == Interrupt::INTERRUPT_NONE
      # master disable interrupts
      @ime = false
      push_onto_stack @pc
      if_reg = $mmu.read_byte 0xFF0F
      case interrupt
      when Interrupt::INTERRUPT_VBLANK
        @pc = 0x40
        $mmu.write_byte(0xFF0F, if_reg & 0xFE)
      when Interrupt::INTERRUPT_LCDSTAT
        @pc = 0x48
        $mmu.write_byte(0xFF0F, if_reg & 0xFD)
      when Interrupt::INTERRUPT_TIMER
        @pc = 0x50
        $mmu.write_byte(0xFF0F, if_reg & 0xFB)
      when Interrupt::INTERRUPT_SERIAL
        @pc = 0x58
        $mmu.write_byte(0xFF0F, if_reg & 0xF7)
      when Interrupt::INTERRUPT_JOYPAD
        @pc = 0x60
        $mmu.write_byte(0xFF0F, if_reg & 0xEF)
      end
      @m = 20
    end

    # reset variables that are set on every instruction
    def reset_tick
      @prefix_cb = false
      @branched = false
      @m = 0
    end
  end
end
