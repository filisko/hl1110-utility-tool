#!/bin/bash
#
# HL-1110 resetter v1.0
#
# Copyright (C) 2017 Filis Futsarov
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

# ASK FOR ADMIN PRIVILEGES
# if [ $EUID != 0 ]; then
#   gksudo "$0" -m "`printf "<b>asdasd</b>\n\nasdasd"`"
#   exit $?
# fi

# CONSTANTS
declare -r APP_NAME="HL-1110 printer utility v1.0"

# rm fucking device!
# ARRAY+=('foo')

function is_valid_printer()
{
  local printer_path="$1"
  if  [ -c "$printer_path" ] && [ $(sudo usb_printerid "$printer_path" | grep "HL-111[0-9] series" -c) -gt 0 ]; then
  # if  [ $(sudo cat "$lp_device" | grep "HL-111[0-9] series" -c) -eq 0 ]; then
    echo 1
  fi
}

# Get HL-1110 connected printers
function get_printers()
{
  local -a lp_devices=($(ls /dev/usb/lp* 2> /dev/null))
  local printer_path=""

  for i in "${!lp_devices[@]}"; do
    printer_path=${lp_devices[$i]}

    if  [ ! $(is_valid_printer "$printer_path") ]; then
    # if  [ $(sudo cat "$lp_device" | grep "HL-111[0-9] series" -c) -eq 0 ]; then
      unset lp_devices[${i}]
    fi
  done

  echo ${lp_devices[@]}
}

# Count number of printers with the result of get_printers()
function count_printers()
{
  local -i count

  if [ -z "$1" ]; then
    count=0
  else
    count=$(($(echo "$1" | grep -o ' ' | wc -l)+1))
  fi

  echo $count
}

# Send PJL commands to the printer
function send_pjl()
{
    local printer_path="$1"
    local pjl_command="$2"

    while true; do
      sleep 0.5

      # Continue only if printer is not busy
      while true; do
        fuser -s "$printer_path"
        if [ $? -ne 0 ]
        then
          break
        fi
      done

      echo -e "\e%-12345X@PJL\r\n@PJL $pjl_command \r\n\e%-12345X" > "$printer_path"
      echo -e "\e" > "$printer_path"
      break
    done
}

# Get printer's output
function get_printer_output()
{
    # Stop trying to get output after 10 seconds
    end_at=$(($SECONDS+10))

    while [ $SECONDS -lt $end_at ]; do
        # while true; do
          output=$(cat "$1")
          lines=$(echo "$output" | wc -l)
          if [ $lines -gt 2 ]
          then
            echo "$output"
            break
          fi
        # done
    done
}

# Get printer's status code
function cmd_get_printer_status_code()
{
    send_pjl "$1" "INFO STATUS"
    declare output=$(get_printer_output "$1")
    declare status=$(echo "$output" | sed -n '/^CODE/p' | cut -d "=" -f2 | tr -d '\n' | tr -d '\r')
    echo "$status"
}


# Get printer's printed pages number
function cmd_get_printer_num_prints()
{
    send_pjl "$1" "INFO PAGECOUNT"

    declare output=$(get_printer_output "$1")
    declare num_prints=$(echo "$output" | sed -n '/^PAGECOUNT=/p' | cut -d "=" -f2 | tr -d '\n' | tr -d '\r')

    echo "$num_prints"
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
    # Operator Intervention Conditions
    40000) echo "Sleep Mode"; ;;
    40010) echo "Install Toner Cartridge or No electric contact with Toner Cartridge"; ;;
    40011) echo "Accessing Toner Cartridge"; ;;
    40019) echo "REMOVE PAPER FROM [bin name]"; ;;
    40020) echo "No MICR Toner or Install MICR Toner Cartridge"; ;;
    40021) echo "Printer Open or NO EP Cart or Close Printer Cover"; ;;
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
    40124) echo "Bad duplexer connection"; ;;
    40128) echo "Drum Error replace Drum Kit"; ;;
    40129) echo "Drum Life Out replace Drum Kit"; ;;
    40130) echo "Drum Life Low replace Drum Kit"; ;;
    40131) echo "Transfer Kit out Replace Kit"; ;;
    40132) echo "TRANSFER KIT LOW REPLACE KIT"; ;;
    40141) echo "WASTE TONER FULL REPLACE DRUM KIT"; ;;
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

# code=$(cmd_get_printer_status_code "/dev/usb/lp0")
# get_message_by_status_code "$code"
#
# cmd_get_printer_num_prints "/dev/usb/lp0"
#
# exit


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
    MSG_MAIN_TEXT="If your HL-1110 printer is turned on and\nconnected to your computer but you still\ncan't continue, please send me an email:\n\n<b>$AUTHOR_EMAIL</b>"
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
      declare printers=$(get_printers)
      declare -i printers_num=$(count_printers "$printers")

      if [ $printers_num -eq 0 ]; then
        zenity \
        --warning \
        --title="$APP_NAME" \
        --text="Woops!\nCouldn't detect a HL-1110 printer connected to your PC." \
        --ok-label="Go back"

        let "NUM_DETECTION_TRIES++"
      elif [ $printers_num -gt 1 ]; then
        zenity \
        --warning \
        --title="$APP_NAME" \
        --text="It seems that you have multiple HL-1110 printers connected. Connect only one please." \
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
                  declare code=$(cmd_get_printer_status_code "$printers")
                  declare message=$(get_message_by_status_code "$code")
                  echo "# Status code: $code\nMessage: $message"
                ) | zenity --progress \
                  --title="$APP_NAME" \
                  --text="Getting printer's status ..." \
                  --pulsate \
                  --width=300 \
                  --no-cancel
              ;;
              "$ACTION_SHOW_NUM_PRINTED")
                (
                  num_prints=$(cmd_get_printer_num_prints "$printers")
                  echo "# Number of printed pages: $num_prints"
                ) | zenity --progress \
                  --title="$APP_NAME" \
                  --text="Getting number of printed pages ..." \
                  --pulsate \
                  --width=300 \
                  --no-cancel
              ;;
              "$ACTION_PRINT_INFO")
                zenity --question \
                --text="This will print a page with your printer's basic information.\n\nDo you want to proceed?" \
                --ellipsize
                if [ $? -eq 0 ]
                then
                  cmd_print_printer_config "$printers"
                fi
              ;;
              "$ACTION_RESET_CONFIG")
                zenity --question \
                --text="This will reset all your printer values.\n\nDo you want to proceed?" \
                --ellipsize
                if [ $? -eq 0 ]
                then
                  (
                    # Takes about 15 seconds to be resetted
                    echo "10"
                    cmd_reset_printer "$printers"
                    echo "20"; sleep 2
                    echo "30"; sleep 2
                    echo "40"; sleep 2
                    echo "50"; sleep 2
                    echo "60"; sleep 2
                    echo "70"; sleep 1
                    echo "80"; sleep 2
                    echo "90"; sleep 2
                    echo "100"
                    echo "# Should be resetted by now!"
                  ) | zenity --progress \
                    --title="$APP_NAME" \
                    --text="Resetting printer ..." \
                    --progress=0 \
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
        --text="HL-1110 printer resetter is a tool that will allow you to ..." \
        --ok-label="Go back" \
        --ellipsize
      else
        exit
      fi
    ;;
  esac
done
