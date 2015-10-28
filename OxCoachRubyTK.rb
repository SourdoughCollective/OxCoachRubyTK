require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'tk'
require 'tkextlib/tile'

#To do - find a way to gray out departure stop names when the bus doesn't stop there (e.g. Notting Hill Gate for X90 etc.)

##VARIABLES
#Destination
@text_select_destination = "1. Please select a destination."

@destination_array = ["London", "Oxford"]
@destination_code = 1 # 0 = to London. 1 = to Oxford.
@destination_text = @destination_array[@destination_code]

#Departure
@text_select_departure = "2. Please select a departure stop."

# 01 = OT to Oxford, 00 = OT to London, 11 = X90 to Oxford, 10 = X90 to London
@departure_array_choose_dest = ["Choose a destination above"]
@departure_array_choose_serv = ["Choose a service below"]
@departure_array_00 = [
  "Choose a departure stop", 
  "Gloucester Green", 
  "Speedwell", 
  "High Street", 
  "St Clements", 
  "Oxford Brookes", 
  "Headington", 
  "Green Road Roundabout", 
  "Thornhill PR", 
  "Lewknor Turn" 
]
@departure_array_01 = [
  "Choose a departure stop", 
  "Victoria", 
  "Grosvenor Gardens", 
  "Marble Arch",
  "Notting Hill Gate", 
  "Shepherds Bush", 
  "Hillingdon", 
  "Lewknor Turn"
]
@departure_array_10 = [
  "Choose a departure stop", 
  "Gloucester Green", 
  "Speedwell", 
  "High Street", 
  "St Clements", 
  "Oxford Brookes", 
  "Headington", 
  "Green Road Roundabout", 
  "Thornhill PR"
]
@departure_array_11 = [
  "Choose a departure stop", 
  "Victoria", 
  "Grosvenor Gardens", 
  "Marble Arch", 
  "Marylebone",
  "Hillingdon"
]

@departure_array = @departure_array_choose_dest #will designate the array in use, out of the five above
@departure_text = @departure_array[0]
@departure_code = nil

#Service
@text_select_service = "3. Please select one coach service, or both."

@service_array = ["Oxford Tube", "X90"]
@service_code = 2 # 0 = OT, 1 = X90, 2 = both, nil = neither

#COMPOSING THE URL
@rtpi_service_array = ["TUBE", "X90"]

@rtpi_00 = { "Choose a departure stop" => ["---"],
             "Gloucester Green" => ["69326524", "451004", "206385"], 
             "Speedwell" => ["69345627", "451308", "205789"], 
             "High Street" => ["69345692", "451811", "206270"], 
             "St Clements" => ["69323265", "452503", "206025"], 
             "Oxford Brookes" => ["69347427", "453606", "206654"], 
             "Headington" => ["69347625", "454635", "207168"], 
             "Green Road Roundabout" => ["69325687", "455361", "207405"], 
             "Thornhill PR" => ["69326542", "456602", "207326"], 
             "Lewknor Turn" => ["69345498", "472100", "197680"] 
           }
@rtpi_01 = { "Choose a departure stop" => ["---"], 
             "Victoria" => ["27245469", "528697", "178724"], 
             "Grosvenor Gardens" => ["27245473", "528784", "179163"], 
             "Marble Arch" => ["27247584", "527883", "180825"],
             "Notting Hill Gate" => ["27245367", "525499", "180511"], 
             "Shepherds Bush" => ["27245482", "524040", "179977"], 
             "Hillingdon" => ["27245426", "507731", "184791"], 
             "Lewknor Turn" => ["69345497", "471775", "197477"]
            }
@rtpi_10 = { "Choose a departure stop" => ["---"], 
             "Gloucester Green" => ["69326498", "451005", "206394"], 
             "Speedwell" => ["69345627", "451308", "205789"], 
             "High Street" => ["69345728", "451821", "206268"], 
             "St Clements" => ["69323265", "452503", "206025"], 
             "Oxford Brookes" => ["69347427", "453606", "206654"], 
             "Headington" => ["69347625", "454635", "207168"], 
             "Green Road Roundabout" => ["69325687", "455361", "207405"], 
             "Thornhill PR" => ["69326542", "456602", "207326"]
             }
@rtpi_11 = { "Choose a departure stop" => ["---"], 
             "Victoria" => ["27248536", "528733", "178814"], 
             "Grosvenor Gardens" => ["27245427", "528800", "178999"], 
             "Marble Arch" => ["27247584", "527883", "180825"], 
             "Marylebone" => ["27248283", "527653", "181867"],
             "Hillingdon" => ["27245426", "507731", "184791"] 
             }

@rtpi_hash = [@rtpi_00, @rtpi_01, @rtpi_10, @rtpi_11]
@rtpi_departure_array = [@departure_array_00, @departure_array_01, @departure_array_10, @departure_array_11]

@text_result = []
@departure_time_array = []
@time_updated_array = []
@time_to_go_str_array = []

def time_stringer(time_in_minutes, time_string_array, array_position)
  if time_in_minutes < 1
    time_string_array[array_position] = "is due"  
  elsif time_in_minutes < 60
      time_string_array[array_position] = time_in_minutes == 1 ? "leaves in 1 minute" : "leaves in #{time_in_minutes} minutes"
  elsif time_in_minutes < 120
      time_string_array[array_position] = "leaves in one hour"
  elsif time_in_minutes >= 120
      time_string_array[array_position] = "leaves in #{time_in_minutes/60} hours"
  end 
  if time_in_minutes > 60 && time_in_minutes%60 != 0
    time_in_minutes%60 == 1 ? time_string_array[array_position] << " and 1 minute" : time_string_array[array_position] << " and #{time_in_minutes} minutes"
  end
end

def look_up(serv_code)
  url_insert_1 = @rtpi_hash[serv_code + serv_code + @destination_code][@departure_code][0]
  url_insert_2 = @rtpi_service_array[serv_code]
  url_insert_3 = @rtpi_hash[serv_code + serv_code + @destination_code][@departure_code][1]
  url_insert_4 = @rtpi_hash[serv_code + serv_code + @destination_code][@departure_code][2]
  rtpi_URL_name = "http://www.oxontime.com/Naptan.aspx?t=departure&sa=#{url_insert_1}&dc=&ac=96&vc=#{url_insert_2}&x=#{url_insert_3}&y=#{url_insert_4}&format=xhtml"
  web_scrape = Nokogiri::HTML(open(rtpi_URL_name))
  @departure_time_array[serv_code] = web_scrape.xpath( "/html/body/div[1]/div[2]/div[2]/div/div/div/table[2]/tbody/tr[1]/td[5]" ).inner_html
  @time_updated_array[serv_code] = Time.now
  time_to_go = 60 * (@departure_time_array[serv_code][0, 2].to_i - @time_updated_array[serv_code].hour) + (@departure_time_array[serv_code][3, 2].to_i - @time_updated_array[serv_code].min)
  time_stringer(time_to_go, @time_to_go_str_array, serv_code)
end

def text_compose(slot)
  @text_result[slot] = "The next #{@service_array[slot]} to #{@destination_text} from #{@departure_text} #{@time_to_go_str_array[slot]} (at #{@departure_time_array[slot]}).\n\nLast updated at #{@time_updated_array[slot].strftime("%H:%M")}."
end

def message_box_text
  @text_result[0] = nil
  @text_result[1] = nil
  if !@destination_code
      @text_result[0] = @text_select_destination
    elsif !@service_code
      @text_result[0] = @text_select_service
    elsif !@departure_code
      @text_result[0] = @text_select_departure
    elsif @service_code == 0
      look_up(0)
      text_compose(0)
    elsif @service_code == 1
      look_up(1)
      text_compose(1)
    elsif @service_code == 2
      if @rtpi_departure_array[@destination_code].include?(@departure_code)
        look_up(0)
        text_compose(0)
      end
      if @rtpi_departure_array[2 + @destination_code].include?(@departure_code)
        look_up(1)
        text_compose(1)
      end
  end
  $messageBox0.value = !@text_result[0] ? " " : @text_result[0]
  $messageBox1.value = !@text_result[1] ? " " : @text_result[1]
end

# USER INPUTS
def user_press_destination_button(destination_code)
  @destination_code = destination_code
  @destination_text = @destination_array[@destination_code]
  alter_departure_list
  @dep_combobox.set( @departure_array[0] )
  message_box_text
end

def user_change_departure_combobox
  if @dep_combobox.get != @departure_array[0]
    @departure_code = @dep_combobox.get
    @departure_text = @dep_combobox.get
  end
  message_box_text
end

def user_check_service
  @service_code = 
    if $OTChecked == 1
        $X90Checked == 1 ? 2 : 0
      elsif $OTChecked == 0
      $X90Checked == 1 ? 1 : nil
    end
  alter_departure_list
  message_box_text
end

def user_reset_all
  @destination_code = nil
  @departure_code = nil
  @departure_array = @departure_array_choose_dest
  @dep_combobox.values = @departure_array
  @dep_combobox.set( @departure_array[0] )
  @service_code = 2
  $OTChecked = 1
  $X90Checked = 1
  message_box_text
end

def alter_departure_list
  if !@destination_code
    @departure_array = @departure_array_choose_dest
  else
  @departure_array = 
    case @service_code
    when 0 then @rtpi_departure_array[@destination_code] # selects the correct array from above. (00, 01, 10, or 11)
    when 1 then @rtpi_departure_array[2 + @destination_code]
    when 2 then @rtpi_departure_array[@destination_code] | @rtpi_departure_array[2 + @destination_code] # Same again: if @destination_code is 0, this creates a combined array from 00 and 10, and if it is 1, this turns 01 and 11 into a combined array.
    when nil then @departure_array_choose_serv
    end
  end
  @dep_combobox.values = @departure_array
end

# GUI
root = TkRoot.new {title "Oxford Coach"}
content = Tk::Tile::Frame.new(root) {padding "2 1 480 480"}.grid(:sticky => 'nsew')
TkGrid.columnconfigure root, 0, :weight => 1; TkGrid.rowconfigure root, 0, :weight => 1

$destinationText1 = TkVariable.new( @destination_array[1] )
$destinationText0 = TkVariable.new( @destination_array[0] )

$departureChoice = TkVariable.new( @departure_array[0] )

$serviceText0 = TkVariable.new( @service_array[0] )
$serviceText1 = TkVariable.new( @service_array[1] )

$OTChecked = TkVariable.new( 1 )
$X90Checked = TkVariable.new( 1 )

$messageBox0 = TkVariable.new( @text_select_destination )
$messageBox1 = TkVariable.new( )

@input_frame = Tk::Tile::Frame.new(content) {padding "2 10"}.grid( :column => 1, :row => 1, :sticky => 'nsew')

@destination_panel = Tk::Tile::Label.new(@input_frame) { text 'Choose destination:' }.grid( :column => 1, :row => 1, :sticky => 'w', :padx => 5, :pady => 5)
@oxford_button = Tk::Tile::Button.new(@input_frame) { textvariable $destinationText1; command 'user_press_destination_button(1)' }.grid( :column => 1, :row => 2, :sticky => 'w', :padx => 5, :pady => 5)
@london_button = Tk::Tile::Button.new(@input_frame) { textvariable $destinationText0; command 'user_press_destination_button(0)' }.grid( :column => 2, :row => 2, :sticky => 'w', :padx => 5, :pady => 5)

@departure_panel = Tk::Tile::Label.new(@input_frame) { text 'Choose departure:' }.grid( :column => 1, :row => 3, :sticky => 'w', :padx => 5, :pady => 5)
@dep_combobox = Tk::Tile::Combobox.new(@input_frame) { textvariable $departureChoice; state 'readonly' }.grid( :column => 1, :row => 4, :columnspan => 2, :sticky => 'w', :padx => 5, :pady => 5)
@dep_combobox.values = @departure_array
@dep_combobox.bind("<ComboboxSelected>") { user_change_departure_combobox }

@service_panel = Tk::Tile::Label.new(@input_frame) { text 'Choose service:' }.grid( :column => 1, :row => 5, :sticky => 'w', :padx => 5, :pady => 5)
@check_OT = Tk::Tile::Checkbutton.new(@input_frame) { textvariable $serviceText0; variable $OTChecked; command 'user_check_service' }.grid( :column => 1, :row => 6, :sticky => 'w', :padx => 5, :pady => 5)
@check_X90 = Tk::Tile::Checkbutton.new(@input_frame) { textvariable $serviceText1; variable $X90Checked; command 'user_check_service' }.grid( :column => 2, :row => 6, :sticky => 'w', :padx => 5, :pady => 5)

@reset_button = Tk::Tile::Button.new(@input_frame) { text 'reset'; command 'user_reset_all' }.grid( :column => 1, :row => 8, :sticky => 'w', :padx => 5, :pady => 5)
@update_button = Tk::Tile::Button.new(@input_frame) { text 'update'; command 'message_box_text' }.grid( :column => 2, :row => 8, :sticky => 'w', :padx => 5, :pady => 5)

@output_frame = Tk::Tile::Frame.new(content) {padding "2 10"}.grid( :column => 4, :row => 1, :sticky => 'nsew')     

@message_box_padding_column = Tk::Tile::Label.new(@output_frame) { text " " }.grid( :column => 1, :padx => 5, :pady => 5, :width => 40 )
@message_box_padding1 = Tk::Tile::Label.new(@output_frame) { text " " }.grid( :row => 2, :columnspan => 2, :padx => 5, :pady => 5, :sticky => 'nsew' )
@message_box0 = Tk::Tile::Label.new(@output_frame) { textvariable $messageBox0 }.grid( :column => 2, :row => 2, :columnspan => 3, :padx => 5, :pady => 5 )
@message_box_padding2 = Tk::Tile::Label.new(@output_frame) { text " " }.grid( :column => 2, :row => 4, :columnspan => 2, :padx => 5, :pady => 5, :sticky => 'nsew' )
@message_box1 = Tk::Tile::Label.new(@output_frame) { textvariable $messageBox1 }.grid( :column => 2, :row => 5, :columnspan => 2, :padx => 5, :pady => 5 )

Tk.mainloop
