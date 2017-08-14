#!/bin/bash
#
# Brother HL-1110 printer utility tool
#
# Copyright (C) 2017 Filis Futsarov <filisfutsarov@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# CONSTANTS
declare -r APP_NAME="HL-1110 utility tool v1.0"

# ASK FOR ADMIN PRIVILEGES
if [ $EUID != 0 ]; then
  gksudo "$0" --description="$APP_NAME"
  exit $?
fi

# If printer path is valid
function is_valid_printer()
{
  local printer_path="$1"
  if  [ -c "$printer_path" ] && [ $(sudo usb_printerid "$printer_path" | grep "HL-111[0-9] series" -c) -gt 0 ]; then
    echo 1
  elif [ -f "$printer_path" ] && ! [ -c "$printer_path" ]; then
    rm "$printer_path"
  fi
}

# Get HL-1110 connected printers
function get_printers()
{
  ls -1 /dev/usb/lp* 2> /dev/null | while read lp_path; do
    if  [ $(is_valid_printer "$lp_path") ]; then
      echo "$lp_path"
    fi
  done
}

# Send PJL commands to the printer
function send_pjl()
{
    local printer_path="$1"
    local pjl_command="$2"

    # Stop trying to send the PJL command after 7 seconds
    end_at=$(($SECONDS+7))

    while [ $SECONDS -lt $end_at ]; do
      if [ $(is_valid_printer "$printer_path") ]; then
          sleep 0.5

          # Continue after printer is not busy (if it's at all!)
          while true; do
            fuser -s "$printer_path"
            if [ $? -ne 0 ]
            then
              break
            fi
          done

          echo -e "\e%-12345X@PJL\r\n@PJL $pjl_command \r\n\e%-12345X" > "$printer_path"
          echo -e "\e" > "$printer_path"

          echo 1
          break
      fi
    done
}

# Get printer's output
function get_printer_output()
{
    # Stop trying to get some output after 5 seconds
    end_at=$(($SECONDS+5))

    while [ "$SECONDS" -lt "$end_at" ]; do
      output=$(cat "$1")
      lines=$(echo "$output" | wc -l)

      if [ $lines -gt 2 ]
      then
        echo "$output"
        break
      fi
    done
}

# Get printer's status code
function cmd_get_printer_status_code()
{
    if [ $(send_pjl "$1" "INFO STATUS") ]; then
        output=$(get_printer_output "$1")

        if [ "$output" ]; then
            status_code=$(echo "$output" | sed -n '/^CODE/p' | cut -d "=" -f2 | tr -d '\n' | tr -d '\r')
            echo "$status_code"
        fi
    fi
}

# Get printer's printed pages number
function cmd_get_printer_num_prints()
{
    if [ $(send_pjl "$1" "INFO PAGECOUNT") ]; then
        output=$(get_printer_output "$1")

        if [ "$output" ]; then
            num_prints=$(echo "$output" | sed -n '/^PAGECOUNT=/p' | cut -d "=" -f2 | tr -d '\n' | tr -d '\r')

            echo "$num_prints"
        fi
    fi
}

# Print printer's config
function cmd_print_printer_config()
{
    send_pjl "$1" "EXECUTE PRTCONFIG"
}

# Reset all printer's values
function cmd_reset_printer()
{
    send_pjl "$1" "EXECUTE REVIVALRESET"
}

# Translate printer's status code to human readable message
function get_message_by_status_code()
{
  case "$1" in
    # Informational Messages
    10001) echo "Ready"; ;;
    10002) echo "Ready (offline)"; ;;
    10003) echo "Warming up"; ;;
    10004) echo "Self Test or Internal Test"; ;;
    10005) echo "Reset, Clearing Memory"; ;;
    10006) echo "Toner Low"; ;;
    10007) echo "Canceling Job"; ;;
    10010) echo "Status Buffer Overflow"; ;;
    10011) echo "Buffer Overflow"; ;;
    10013) echo "Self Test"; ;;
    10014) echo "Printing Test"; ;;
    10015) echo "Printing Font List"; ;;
    10016) echo "Engine Test"; ;;
    10017) echo "Printing Demo Page"; ;;
    10018) echo "Resetting Menus to Defaults"; ;;
    10019) echo "Resetting Active IO"; ;;
    10020) echo "Resetting all IO"; ;;
    10021) echo "Restoring Factory Settings"; ;;
    10022) echo "Printing Configuration Page"; ;;
    10023) echo "Processing Job"; ;;
    10024) echo "Press select to form feed or Data received"; ;;
    10025) echo "Access Denied"; ;;
    10026) echo "No Job to Cancel"; ;;
    10027) echo "Clearing paper path"; ;;
    10028) echo "Printing error log"; ;;
    10029) echo "Formfeeding"; ;;
    10030) echo "Print Job Received"; ;;
    10031) echo "Engine Cleaning"; ;;
    # PJL Parser Errors
    20001) echo "Generic syntax error (entire PJL command ignored)"; ;;
    20002) echo "Unsupported command"; ;;
    20004) echo "Unsupported personality, system, or I/O port"; ;;
    20005) echo "PJL command buffer overflow"; ;;
    20006) echo "Illegal character or line terminated by the Universal Exit Language command"; ;;
    20007) echo "<WS> or [<CR>]<LF> missing after closing quotes"; ;;
    20008) echo "Invalid character in an alphanumeric value"; ;;
    20009) echo "Invalid character in a numeric value"; ;;
    20010) echo "Invalid character at the start of a string, alphanumeric value, or numeric value"; ;;
    20011) echo "String missing closing double-quote character"; ;;
    20012) echo "Numeric value starts with a decimal point"; ;;
    20013) echo "Numeric value does not contain any digits"; ;;
    20014) echo "No alphanumeric value after command modifier"; ;;
    20015) echo "Option name and equal sign encountered, but the value field is missing"; ;;
    20016) echo "More than one command modifier"; ;;
    20017) echo "Command modifier encountered after an option(command modifier must precede option)"; ;;
    20018) echo "Command not an alphanumeric value"; ;;
    20019) echo "Numeric value encountered when an alphanumeric value expected"; ;;
    20020) echo "String encountered when an alphanumeric valueexpected"; ;;
    20021) echo "Unsupported command modifier"; ;;
    20022) echo "Command modifier missing"; ;;
    20023) echo "Option missing"; ;;
    20024) echo "Extra data received after option name (used for commands like SET that limit the number of options supported)"; ;;
    20025) echo "Two decimal points in a numeric value"; ;;
    20026) echo "Invalid binary value"; ;;
    # PJL Parser Warnings
    25001) echo "Generic warning error (part of the PJL command ignored)"; ;;
    25002) echo "PJL prefix missing"; ;;
    25003) echo "Alphanumeric value too long"; ;;
    25004) echo "String too long"; ;;
    25005) echo "Numeric value too long"; ;;
    25006) echo "Unsupported option name"; ;;
    25007) echo "Option name requires a value which is missing"; ;;
    25008) echo "Option name requires a value of a different type"; ;;
    25009) echo "Option name received with a value, but this option does not support values"; ;;
    25010) echo "Same option name received more than once"; ;;
    25011) echo "Ignored option name due to value underflow or overflow"; ;;
    25012) echo "Value for option experienced data loss due to data conversion (value truncated or rounded)"; ;;
    25013) echo "Value for option experienced data loss due to value being out of range; the value used was the closest supported limit"; ;;
    25014) echo "Value is of the correct type, but is out of range (value wasignored)"; ;;
    25016) echo "Option name received with an alphanumeric value, butthis value is not supported"; ;;
    25017) echo "String empty, option ignored"; ;;
    25018) echo "A Universal Exit Language command wasexpected but not found"; ;;
    # PJL Semantic Errors
    27001) echo "Generic semantic error"; ;;
    27002) echo "EOJ command encountered without a previouslymatching JOB command. An EOJ command does nothave a matching JOB command if the number of validEOJ commands received is greater than the number ofvalid JOB commands received"; ;;
    27003) echo "Password protected—attempted to change NVRAM value when password is set and the job is not a secure PJL job"; ;;
    27004) echo "Cannot modify the value of a read-only variable"; ;;
    27005) echo "Can only use DEFAULT with this variable; cannot use SET"; ;;
    27006) echo "Attempted to pass a NULL string to a command orcommand option that requires the string to contain atleast one character"; ;;
    27007) echo "Attempted to DEFAULT a variable which can only be SET"; ;;
    # Operator Intervention Conditions
    40000) echo "Sleep Mode"; ;;
    40010) echo "Install Toner Cartridge or No electric contact with Toner Cartridge"; ;;
    40011) echo "Accessing Toner Cartridge"; ;;
    40019) echo "Remove paper"; ;;
    40020) echo "No MICR Toner or Install MICR Toner Cartridge"; ;;
    40021) echo "Printer Open. Close Printer Cover"; ;;
    40022) echo "Paper Jam or Remove Paper Jam"; ;;
    40024) echo "FE Cartridge"; ;;
    40026) echo "PC Install or Install Tray 2"; ;;
    40038) echo "Low Toner, PRESS GO KEY"; ;;
    40046) echo "FI Insert Cartridge"; ;;
    40047) echo "FR Remove Cartridge"; ;;
    40048) echo "[PJL OPMSG]"; ;;
    40049) echo "[PJL STMSG]"; ;;
    40050) echo "50 Service or 50 FUSER Error, Cycle Power"; ;;
    40051) echo "51 ERROR or 51 Printer Error, Cycle Power"; ;;
    40052) echo "52 ERROR or 52 Printer Error, Cycle Power"; ;;
    40053) echo "53-xy-zz ERROR"; ;;
    40054) echo "54 ERROR"; ;;
    40055) echo "55 ERROR"; ;;
    40056) echo "56 ERROR"; ;;
    40057) echo "57 Service or 57 Motor Failure"; ;;
    40058) echo "58 SERVICE or FAN Motor Failure"; ;;
    40059) echo "59 ERROR"; ;;
    40061) echo "61.x SERVICE"; ;;
    40062) echo "62.x SERVICE"; ;;
    40063) echo "63 SERVICE"; ;;
    40064) echo "64 SERVICE or Printer Error, Cycle Power"; ;;
    40065) echo "65 SERVICE"; ;;
    40066) echo "External paper handling device failure"; ;;
    40067) echo "67 SERVICE"; ;;
    40068) echo "69 SERVICE"; ;;
    40069) echo "70 ERROR"; ;;
    40070) echo "71 ERROR"; ;;
    40071) echo "72 SERVICE"; ;;
    40079) echo "Printer Manually Taken Offline"; ;;
    40080) echo "EE Incompatible or LC Incompatible"; ;;
    40083) echo "FS Disk Failure or 311.1.1 Disk Failure or Volume 0 FAILURE (Volume 0 will be indicated as either DISK, FLASH, or RAMDISK as appropriate)"; ;;
    40089) echo "Incomplete Tray 3 Installed"; ;;
    40090) echo "Incompatible Envelope Feeder Installed"; ;;
    40092) echo "81 SERVICE (XXX)"; ;;
    40093) echo "Remove Duplex Jam"; ;;
    40096) echo "41.3 Unexpected Paper Size Check Paper in Tray"; ;;
    40099) echo "56.1 ERROR PRESS SELECT KEY"; ;;
    40100) echo "56.2 ERROR PRESS SELECT KEY"; ;;
    40102) echo "FINISHER ALIGN ERROR [BIN NAME]"; ;;
    40103) echo "FINISH LIMIT REACHED [BIN NAME]"; ;;
    40104) echo "INPUT DEVICE FEED PATH OPEN"; ;;
    40105) echo "OUTPUT DEVICE DELIVERY PATH OPEN"; ;;
    40106) echo "INPUT OPERATION ERROR X.YY"; ;;
    40107) echo "OUTPUT OPERATION ERROR X.YY"; ;;
    40116) echo "Volume 1 FAILURE (Failure on Volume 1. Volume 1 will be indicated as either DISK, FLASH, or RAMDISK as appropriate)"; ;;
    40118) echo "Volume 2 FAILURE (Failure on Volume2 . Volume 2 is indicated as either DISK, FLASH, or RAMDISK as appropriate."; ;;
    40119) echo "Paper Misfeed"; ;;
    40120) echo "Open face-up output bin"; ;;
    40121) echo "Close face-up output bin"; ;;
    40122) echo "Duplexer must be installed"; ;;
    40123) echo "Duplexer error, remove duplexer"; ;;
    40124) echo "Bad duplexer Example of messages: connection"; ;;
    40128) echo "Drum Error replace Drum Kit"; ;;
    40129) echo "Drum Life Out replace Drum Kit"; ;;
    40130) echo "Drum Life Low replace Drum Kit"; ;;
    40131) echo "Transfer Kit out replace Kit"; ;;
    40132) echo "Transfer Kit low replace Kit"; ;;
    40141) echo "Waste toner full, replace Drum Kit"; ;;
    40142) echo "Install Drum Kit"; ;;
    40143) echo "Reinstall Transfer Belt"; ;;
    40144) echo "Press Go to Print, Press Select to Change Toner"; ;;
    40146) echo "41.5 Unexpected Paper Type, Check Paper in Tray"; ;;
    # Hardware Errors
    50000) echo "General Hardware Failure"; ;;
    50001) echo "ROM or RAM Error, ROM Checksum Failed"; ;;
    50002) echo "RAM Error, RAM Test Failed"; ;;
    50003) echo "Engine Fuser Error"; ;;
    50004) echo "Engine Beam Detect Error"; ;;
    50005) echo "Engine Scanner Error"; ;;
    50006) echo "Engine Fan Error"; ;;
    50007) echo "Engine Communications Error"; ;;
    50008) echo "FUSER Error Cycle Power or Low FUSER Temperature"; ;;
    50009) echo "FUSER Error Cycle Power or FUSER took too long to Warm Up"; ;;
    50010) echo "FUSER Error Cycle Power or FUSER too hot"; ;;
    50011) echo "FUSER Error Cycle Power or bad FUSER"; ;;
    50012) echo "Error Press Select Key or Beam Detect Malfunction"; ;;
    50013) echo "Error Press Select Key or Laser Malfunction"; ;;
    50014) echo "Error Press Select Key or Scanner Startup Failure"; ;;
    50015) echo "Error Press Select Key or Scanner Rotation Failure"; ;;
    50016) echo "Fan Failure Call Service or Fan Motor 1 Failure"; ;;
    50017) echo "Fan Failure Call Service or Fan Motor 2 Failure"; ;;
    50018) echo "Fan Failure Call Service or Fan Motor 3 Failure"; ;;
    50019) echo "Fan Failure Call Service or Fan Motor 4 Failure"; ;;
    50020) echo "Upper Input Tray Lifter Malfunction"; ;;
    50021) echo "Lower Input Tray Lifter Malfunction"; ;;
    50022) echo "Printer Error Cycle Power or Multipurpose Try Lifter Malfunction"; ;;
    50023) echo "Printer Error Cycle Power or Main Motor Startup Failure"; ;;
    50024) echo "Printer Error Cycle Power or Main Motor Rotation Failure"; ;;
    50025) echo "Finisher Malfunction [BIN NAME] or External Binding Device Has a Malfunction"; ;;
    50026) echo "Device Error X.YY Cycle Power or An External Device has Reporte a Malfunction"; ;;
    50027) echo "Duplex Error Check Duplex Unit or Duplex Unit Guide Failed and Requires Service"; ;;
    50028) echo "Error Press Select Key or Communication Failure between Formatter and Engine"; ;;
    50029) echo "Printer Error Cycle Power"; ;;
    50030) echo "Fan Motor 5 Failure"; ;;
    50031) echo "Fan Motor 6 Failure"; ;;
    50032) echo "Fan Motor 7 Failure"; ;;
    50033) echo "Fan Motor 8 Failure"; ;;
    50599) echo "Processor Error, Power Cycle"; ;;
    505[0-9][0-9]) echo "Firmware Error, Power Cycle"; ;;
    *)
      echo "Unknown"
    ;;
  esac
}


# Variables
declare -i NUM_DETECTION_TRIES=0

while true; do
  if [ $NUM_DETECTION_TRIES -eq 0 ]; then
    MSG_MAIN_TEXT="<b>Welcome to $APP_NAME</b>\n\nIs your HL-1110 printer turned on and connected to your computer?"
    MSG_MAIN_OK="Yes, continue"
  elif [ $NUM_DETECTION_TRIES -eq 1 ]; then
    MSG_MAIN_TEXT="Please, make sure your HL-1110 printer is turned\non and connected to your computer, then try again."
    MSG_MAIN_OK="Try again"
  else
    MSG_MAIN_TEXT="If your HL-1110 printer is turned on and\nconnected to your computer but you still\ncan't continue, please send me an email as detailed as possible:\n\n<b>$AUTHOR_EMAIL</b>"
  fi

  main=$(
    zenity \
    --question\
    --title="$APP_NAME" \
    --text="$MSG_MAIN_TEXT" \
    --extra-button="About" \
    --cancel-label="Exit" \
    --ok-label="$MSG_MAIN_OK" \
    --ellipsize
  )

  case $? in
    0)
    #   declare printers="/dev/usb/lp1"
      declare printers=$(get_printers)
      declare -i num_printers=$(grep -o "/" <<< "$printers" | wc -l | awk '{print $1/3}')

      if [ "$num_printers" -eq 0 ]; then
        zenity \
        --warning \
        --title="$APP_NAME" \
        --text="Woops!\nCouldn't detect a HL-1110 printer connected to your PC." \
        --ok-label="Go back"

        let "NUM_DETECTION_TRIES++"
      elif [ "$num_printers" -gt 1 ]; then
        zenity \
        --warning \
        --title="$APP_NAME" \
        --text="You have "$num_printers" HL-1110 printers connected.\nLeave only one please." \
        --ellipsize \
        --ok-label="Go back"
      else
        while true; do
          # ACTIONS
          ACTION_SHOW_STATUS="Show current printer's status"
          ACTION_SHOW_NUM_PRINTED="Show number of printed pages"
          ACTION_PRINT_INFO="Print printer's basic information"
          ACTION_RESET_CONFIG="Reset all printer's values (toner, drum, pagecount, etc.)"

          action=$(
            zenity --list \
            --title="$APP_NAME" \
            --text="Select an action to perform on the connected HL-1110 printer." \
            --column="Action" \
            --width=400 --height=250 \
            --cancel-label="Exit" \
            --ok-label="Execute" \
              "$ACTION_SHOW_STATUS" \
              "$ACTION_SHOW_NUM_PRINTED" \
              "$ACTION_PRINT_INFO" \
              "$ACTION_RESET_CONFIG"
          )

          if [ $? -eq 0 ]; then
            case $action in
              "$ACTION_SHOW_STATUS")
                (
                  status_code=$(cmd_get_printer_status_code "$printers")

                  if [ "$status_code" ]; then
                      status_message=$(get_message_by_status_code "$status_code")
                      echo "# Status code: $status_code\nMessage: $status_message"
                  else
                      echo "# Could not get printer's current status."
                  fi
                ) | zenity --progress \
                  --title="$APP_NAME" \
                  --text="Trying to get printer's current status ..." \
                  --pulsate \
                  --ok-label="OK" \
                  --width=300 \
                  --no-cancel
              ;;
              "$ACTION_SHOW_NUM_PRINTED")
                (
                  num_prints=$(cmd_get_printer_num_prints "$printers")

                  if [ "$num_prints" ]; then
                    echo "# Number of printed pages: $num_prints"
                  else
                    echo "# Could not get printer's number of printed pages."
                  fi
                ) | zenity --progress \
                  --title="$APP_NAME" \
                  --text="Trying to get number of printed pages ..." \
                  --pulsate \
                  --ok-label="OK" \
                  --width=300 \
                  --no-cancel
              ;;
              "$ACTION_PRINT_INFO")
                zenity --question \
                --text="This will print a page with your printer's basic information.\n\nDo you want to proceed?" \
                --ellipsize
                if [ $? -eq 0 ]
                then
                  (
                    if [ $(cmd_print_printer_config "$printers") ]; then
                        echo "# Print job successfully sent!"
                    else
                        echo "# Printing job could not be sent."
                    fi
                  ) | zenity --progress \
                    --title="$APP_NAME" \
                    --text="Sending print basic information job ..." \
                    --pulsate \
                    --ok-label="OK" \
                    --width=300 \
                    --no-cancel
                fi
              ;;
              "$ACTION_RESET_CONFIG")
                zenity --question \
                --text="This will reset all your printer values.\n\nDo you want to proceed?" \
                --ellipsize
                if [ $? -eq 0 ]
                then
                  (
                    echo "10"
                    if [ $(cmd_reset_printer "$printers") ]; then
                        # Better don't do anything during 15 seconds
                        echo "20"; sleep 2
                        echo "# Resetting now, please wait 10 seconds ..."
                        echo "30"; sleep 2
                        echo "40"; sleep 2
                        echo "50"; sleep 2
                        echo "60"; sleep 2
                        echo "70"; sleep 1
                        echo "80"; sleep 2
                        echo "90"; sleep 2
                        echo "# The printer should be resetted by now!"
                    else
                        echo "# Printer could not be resetted."
                    fi
                    echo "100"

                  ) | zenity --progress \
                    --title="$APP_NAME" \
                    --text="Trying to reset the printer ..." \
                    --progress=0 \
                    --ok-label="OK" \
                    --width=300 \
                    --no-cancel
                fi
              ;;
              *)
                  zenity \
                  --warning \
                  --title="$APP_NAME" \
                  --text="Select an action to be executed please." \
                  --ok-label="Go back" \
                  --ellipsize
              ;;
            esac
          else
            exit
          fi
        done
      fi
    ;;
    1)
      if [ "$main" == "About" ]; then
        zenity \
        --info \
        --title="$APP_NAME" \
        --text="To read more information about this tool please visit: https://github.com/filisko/hl1110-utility-tool" \
        --ok-label="Good to know!" \
        --ellipsize
      else
        exit
      fi
    ;;
  esac
done
