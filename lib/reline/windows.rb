module Reline
  VK_LMENU = 0xA4
  STD_OUTPUT_HANDLE = -11
  @@getwch = Win32API.new('msvcrt', '_getwch', [], 'I')
  @@kbhit = Win32API.new('msvcrt', '_kbhit', [], 'I')
  @@GetKeyState = Win32API.new('user32', 'GetKeyState', ['L'], 'L')
  @@GetConsoleScreenBufferInfo = Win32API.new('kernel32', 'GetConsoleScreenBufferInfo', ['L', 'P'], 'L')
  @@SetConsoleCursorPosition = Win32API.new('kernel32', 'SetConsoleCursorPosition', ['L', 'L'], 'L')
  @@GetStdHandle = Win32API.new('kernel32', 'GetStdHandle', ['L'], 'L')
  @@FillConsoleOutputCharacter = Win32API.new('kernel32', 'FillConsoleOutputCharacter', ['L', 'L', 'L', 'L', 'P'], 'L')
  @@ScrollConsoleScreenBuffer = Win32API.new('kernel32', 'ScrollConsoleScreenBuffer', ['L', 'P', 'P', 'L', 'P'], 'L')
  @@hConsoleHandle = @@GetStdHandle.call(STD_OUTPUT_HANDLE)
  @@buf = []

  def getwch
    while @@kbhit.call == 0
      sleep(0.001)
    end
    result = []
    until @@kbhit.call == 0
      ret = @@getwch.call
      begin
        result.concat(ret.chr(Encoding::UTF_8).encode(Encoding.default_external).bytes)
      rescue Encoding::UndefinedConversionError
        result << ret
        result << @@getwch.call if ret == 224
      end
    end
    result
  end

  def getc
    unless @@buf.empty?
      return @@buf.shift
    end
    input = getwch
    alt = (@@GetKeyState.call(VK_LMENU) & 0x80) != 0
    if input.size > 1
      @@buf.concat(input)
    else # single byte
      case input[0]
      when 0x00
        getwch
        alt = false
        input = getwch
        @@buf.concat(input)
      when 0xE0
        @@buf.concat(input)
        input = getwch
        @@buf.concat(input)
      when 0x03
        @@buf.concat(input)
      else
        @@buf.concat(input)
      end
    end
    if alt
      "\e".ord
    else
      @@buf.shift
    end
  end

  def self.get_screen_size
    csbi = 0.chr * 24
    @@GetConsoleScreenBufferInfo.call(@@hConsoleHandle, csbi)
    csbi[0, 4].unpack('SS')
  end

  def self.cursor_pos
    csbi = 0.chr * 24
    @@GetConsoleScreenBufferInfo.call(@@hConsoleHandle, csbi)
    x = csbi[4, 2].unpack('s*').first
    y = csbi[6, 4].unpack('s*').first
    CursorPos.new(x, y)
  end

  def self.move_cursor_column(val)
    @@SetConsoleCursorPosition.call(@@hConsoleHandle, cursor_pos.y * 65536 + val)
  end

  def self.move_cursor_up(val)
    if val > 0
      @@SetConsoleCursorPosition.call(@@hConsoleHandle, (cursor_pos.y - val) * 65536 + cursor_pos.x)
    elsif val < 0
      move_cursor_down(-val)
    end
  end

  def self.move_cursor_down(val)
    if val > 0
      @@SetConsoleCursorPosition.call(@@hConsoleHandle, (cursor_pos.y + val) * 65536 + cursor_pos.x)
    elsif val < 0
      move_cursor_up(-val)
    end
  end

  def self.erase_after_cursor
    csbi = 0.chr * 24
    @@GetConsoleScreenBufferInfo.call(@@hConsoleHandle, csbi)
    cursor = csbi[4, 4].unpack('L').first
    written = 0.chr * 4
    @@FillConsoleOutputCharacter.call(@@hConsoleHandle, 0x20, get_screen_size.first - cursor_pos.x, cursor, written)
  end

  def self.scroll_down(val)
    return if val.zero?
    scroll_rectangle = [0, val, get_screen_size.last, get_screen_size.first].pack('s4')
    destination_origin = 0 # y * 65536 + x
    fill = [' '.ord, 0].pack('SS')
    @@ScrollConsoleScreenBuffer.call(@@hConsoleHandle, scroll_rectangle, nil, destination_origin, fill)
  end

  def self.clear_screen
    # TODO: Use FillConsoleOutputCharacter and FillConsoleOutputAttribute
    print "\e[2J"
    print "\e[1;1H"
  end

  def self.set_screen_size(rows, columns)
    raise NotImplementedError
  end

  def prep
    # do nothing
    nil
  end

  def deprep(otio)
    # do nothing
  end
end
