#!/bin/bash

dpkg-deb --build deb
zenity --info --text 'Generado!'
