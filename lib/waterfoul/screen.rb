module Waterfoul
  class Screen

    SCREEN_WIDTH = 160
    SCREEN_HEIGHT = 144

    def initialize
      SDL.InitSubSystem SDL::INIT_VIDEO
      @buffer = FFI::MemoryPointer.new :uint32, SCREEN_WIDTH * SCREEN_HEIGHT
      @window = SDL.CreateWindow 'waterfoul', 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, SDL::SDL_WINDOW_RESIZABLE
      @renderer = SDL.CreateRenderer @window, -1, 0
      SDL.SetHint "SDL_RENDER_SCALE_QUALITY",  "linear"
      SDL.RenderSetLogicalSize(@renderer, SCREEN_WIDTH, SCREEN_HEIGHT)
      @texture = SDL.CreateTexture @renderer, SDL::PIXELFORMAT_ARGB8888, 1, SCREEN_WIDTH, SCREEN_HEIGHT
    end

    def render(framebuffer)
      @buffer.write_array_of_uint32 framebuffer
      SDL.UpdateTexture @texture, nil, @buffer, SCREEN_WIDTH * 4
      SDL.RenderClear @renderer
      SDL.RenderCopy @renderer, @texture, nil, nil
      SDL.RenderPresent @renderer
    end
  end
end
