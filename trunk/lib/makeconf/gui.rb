class Makeconf::GUI

  def initialize(project_list)
    require 'tk'

    @project_list = project_list

    @mainMessage = TkVariable.new 
    @mainMessage.set_value 'hi'

    @root = TkRoot.new() { 
        title "Installation" 
    }

    @mainFrame = TkFrame.new(@root) {
        height      400
        width       400
        background  'white'
        borderwidth 5
        relief      'groove'
        padx        10
        pady        10
        pack('side' => 'top')
    }

    @mainText = TkLabel.new(@mainFrame) {
        background  'white'
        place('relx'=>0.0, 'rely' => 0.0)
    }
    @mainText.configure('textvariable', @mainMessage)

    @cancelButton = TkButton.new(@root) { 
        text "Cancel" 
        command proc {
            exit 1
        }
        pack('side' => 'right')
    }

    @nextButton = TkButton.new(@root) { 
        text "Next" 
        pack('side' => 'right')
    }
#nextButton.configure('command', proc { mainMessage.set_value 'You click it' })

    @backButton = TkButton.new(@root) { 
        text "Back" 
        pack('side' => 'right')
    }
  end

  def main_loop
    intro_page
    Tk.mainloop()
  end

  def intro_page
    @mainMessage.set_value "This will install #{@project_list.id} on your computer"
    @backButton.configure('state', 'disabled')
    @nextButton.configure('command', proc { 
            @backButton.configure('state', 'normal')
            license_page 
            })
  end

  def license_page
    @mainMessage.set_value "Here is the license"
  end

end

__END__
# UNUSED: might use for showing error messages if "require 'tk'" fails
#
class Makeconf::GUI::Minimal

  if Platform.is_windows?
    require 'dl'
  end

  def initialize
  end

  # Display a graphical message box
  def message_box(txt, title, buttons=0)
    if Platform.is_windows?

# FIXME: add conditional

#Ruby 1.8:
#      user32 = DL.dlopen('user32')
#      msgbox = user32['MessageBoxA', 'ILSSI']
#      r, rs = msgbox.call(0, txt, title, buttons)
#      return r

#Ruby 1.9:
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

end
