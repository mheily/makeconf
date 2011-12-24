class Makeconf::GUI

  if Platform.is_windows?
    require 'dl'
  end

  def initialize
    bootstrap_wxruby
    require 'makeconf/wxapp'
    @app = Makeconf::WxApp.new
  end

  def run
    @app.main_loop
   # XXX-FIXME kludge for Windows testing
     if Platform.is_windows?
        system "nmake"
        system "pause"
     end
  end

  # Display a graphical message box
  def message_box(txt, title, buttons=0)
    if Platform.is_windows?
#Ruby 1.8
#      user32 = DL.dlopen('user32')
#      msgbox = user32['MessageBoxA', 'ILSSI']
#      r, rs = msgbox.call(0, txt, title, buttons)
#      return r
    user32 = DL.dlopen('user32')
    msgbox = DL::CFunc.new(user32['MessageBoxA'], DL::TYPE_LONG, 'MessageBox')
    r, rs = msgbox.call([0, txt, title, buttons].pack('L!ppL!').unpack('L!*'))
    return r
    elsif Platform.is_linux?
      #XXX-scrub txt to eliminate "'" character
      cmd = "zenity --text='#{txt}' " + (buttons > 0 ? '--question' : '--info')
      rv = system cmd
      return rv == true ? 1 : 0
    else
      throw 'STUB'
    end
  end

  # Display an informational message with a single 'OK' button
  def notice(txt, title)
    message_box(txt, title, 0)
  end

  # Display an confirmation message with an OK button and CANCEL button
  def confirm(txt, title)
    return (message_box(txt, title, 1) == 1) ? true : false
  end

  private

  def bootstrap_wxruby
    begin
      require 'wx'
    rescue LoadError
      if confirm('This program requires wxRuby. Download and install it?', 'wxRuby Required')
        # Ruby 1.8
        #system 'gem install wxruby'
        system 'gem install wxruby-ruby19'
      else
        notice('Installation cannot proceed. Please install wxRuby and try again.', 'Installation failed')
        exit 1
      end
    end
  end
end
