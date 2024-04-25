#!/usr/bin/env bash
# Update BirdNET-Pi
source /etc/birdnet/birdnet.conf
trap 'exit 1' SIGINT SIGHUP
USER=$(awk -F: '/1000/ {print $1}' /etc/passwd)
HOME=$(awk -F: '/1000/ {print $6}' /etc/passwd)
my_dir=$HOME/BirdNET-Pi/scripts

# Sets proper permissions and ownership
#sudo -E chown -R $USER:$USER $HOME/*
#sudo chmod -R g+wr $HOME/*
find $HOME/Bird* -type f ! -perm -g+wr -exec chmod g+wr {} + 2>/dev/null
find $HOME/Bird* -not -user $USER -execdir sudo -E chown $USER:$USER {} \+
chmod 666 ~/BirdNET-Pi/scripts/*.txt
chmod 666 ~/BirdNET-Pi/*.txt
find $HOME/BirdNET-Pi -path "$HOME/BirdNET-Pi/birdnet" -prune -o -type f ! -perm /o=w -exec chmod a+w {} \;

# remove world-writable perms
chmod -R o-w ~/BirdNET-Pi/templates/*

chmod +x ~/BirdNET-Pi/scripts/guano_edit.py
chmod +x ~/BirdNET-Pi/scripts/batnet_timer.sh
chmod +x ~/BirdNET-Pi/scripts/sun_info.py
chmod +x ~/BirdNET-Pi/scripts/switch_classifier.sh
$HOME/BirdNET-Pi/birdnet/bin/pip3 install python-dateutil datetime

install_batnet_timer_server() {
  cat << EOF > $HOME/BirdNET-Pi/templates/batnet_timer_server.service
[Unit]
Description=BatNET Dusk/Dawn Starter Server
[Service]
Restart=always
Type=simple
RestartSec=5
User=${USER}
ExecStart=/usr/local/bin/batnet_timer.sh
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/batnet_timer_server.service /usr/lib/systemd/system
  sudo systemctl enable batnet_timer_server.service
}

if grep -q 'php7.4-' /etc/caddy/Caddyfile &>/dev/null; then
  sed -i 's/php7.4-/php-/' /etc/caddy/Caddyfile
fi

if ! grep SWITCH_TO_BIRD /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "SWITCH_TO_BIRD=\"false\"" >> /etc/birdnet/birdnet.conf
  sudo -u $USER echo "BIRD_CLASSIFIER=\"BIRDS\"" >> /etc/birdnet/birdnet.conf
fi


if ! grep LAST_BAT_CLASSIFIER /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "LAST_BAT_CLASSIFIER=\"$BAT_CLASSIFIER\"" >> /etc/birdnet/birdnet.conf
fi

if ! grep BAT_TIMER /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "BAT_TIMER=\"false\"" >> /etc/birdnet/birdnet.conf
  sudo -u $USER echo "BAT_DUSK=\"18:00\"" >> /etc/birdnet/birdnet.conf
  sudo -u $USER echo "BAT_DAWN=\"06:00\"" >> /etc/birdnet/birdnet.conf
  install_batnet_timer_server
  sudo systemctl start batnet_timer_server.service
fi

if ! grep NOISERED /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "NOISERED=\"false\"" >> /etc/birdnet/birdnet.conf
  sudo -u $USER echo "NOISE_PROF=\"BattyBirdNET-Analyzer/checkpoints/bats/mic-noise/audiomoth_v12.prof\"" >> /etc/birdnet/birdnet.conf
  sudo -u $USER echo "NOISE_PROF_FACTOR=\"0.22\"" >> /etc/birdnet/birdnet.conf
fi

if ! grep INPUT_NOISERED /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "INPUT_NOISERED=\"false\"" >> /etc/birdnet/birdnet.conf
fi

if ! grep BAT_SUNTIMER /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "BAT_SUNTIMER=\"false\"" >> /etc/birdnet/birdnet.conf
  chmod +x ~/BirdNET-Pi/scripts/sun_info.py
fi

if ! grep INPUT_SPECTROGRAM_COLOR /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "INPUT_SPECTROGRAM_COLOR=\"\"" >> /etc/birdnet/birdnet.conf
fi

# Create blank sitename as it's optional. First time install will use $HOSTNAME.
if ! grep SITE_NAME /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "SITE_NAME=\"\"" >> /etc/birdnet/birdnet.conf
fi

if ! grep PRIVACY_THRESHOLD /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "PRIVACY_THRESHOLD=0" >> /etc/birdnet/birdnet.conf
  git -C $HOME/BirdNET-Pi rm $my_dir/privacy_server.py
fi
if [ -f $my_dir/privacy_server ] || [ -L /usr/local/bin/privacy_server.py ];then
  rm -f $my_dir/privacy_server.py
  rm -f /usr/local/bin/privacy_server.py
fi

# Adds python virtual-env to the python systemd services
if ! grep 'BirdNET-Pi/birdnet/' $HOME/BirdNET-Pi/templates/birdnet_server.service &>/dev/null || ! grep 'BirdNET-Pi/birdnet' $HOME/BirdNET-Pi/templates/chart_viewer.service &>/dev/null;then
  sudo -E sed -i "s|ExecStart=.*|ExecStart=$HOME/BirdNET-Pi/birdnet/bin/python3 /usr/local/bin/server.py|" ~/BirdNET-Pi/templates/birdnet_server.service
  sudo -E sed -i "s|ExecStart=.*|ExecStart=$HOME/BirdNET-Pi/birdnet/bin/python3 /usr/local/bin/daily_plot.py|" ~/BirdNET-Pi/templates/chart_viewer.service
  sudo systemctl daemon-reload && restart_services.sh
fi

if grep privacy ~/BirdNET-Pi/templates/birdnet_server.service &>/dev/null;then
  sudo -E sed -i 's/privacy_server.py/server.py/g' \
    ~/BirdNET-Pi/templates/birdnet_server.service
  sudo systemctl daemon-reload
  restart_services.sh
fi
if ! grep APPRISE_NOTIFICATION_TITLE /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "APPRISE_NOTIFICATION_TITLE=\"New BirdNET-Pi Detection\"" >> /etc/birdnet/birdnet.conf
fi
if ! grep APPRISE_NOTIFICATION_BODY /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "APPRISE_NOTIFICATION_BODY=\"A \$sciname \$comname was just detected with a confidence of \$confidence\"" >> /etc/birdnet/birdnet.conf
fi
if ! grep APPRISE_NOTIFY_EACH_DETECTION /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "APPRISE_NOTIFY_EACH_DETECTION=0 " >> /etc/birdnet/birdnet.conf
fi
if ! grep APPRISE_NOTIFY_NEW_SPECIES /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "APPRISE_NOTIFY_NEW_SPECIES=0 " >> /etc/birdnet/birdnet.conf
fi
if ! grep APPRISE_NOTIFY_NEW_SPECIES_EACH_DAY /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "APPRISE_NOTIFY_NEW_SPECIES_EACH_DAY=0 " >> /etc/birdnet/birdnet.conf
fi
if ! grep APPRISE_MINIMUM_SECONDS_BETWEEN_NOTIFICATIONS_PER_SPECIES /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "APPRISE_MINIMUM_SECONDS_BETWEEN_NOTIFICATIONS_PER_SPECIES=0 " >> /etc/birdnet/birdnet.conf
fi

# If the config does not contain the DATABASE_LANG setting, we'll want to add it.
# Defaults to not-selected, which config.php will know to render as a language option.
# The user can then select a language in the web interface and update with that.
if ! grep DATABASE_LANG /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "DATABASE_LANG=not-selected" >> /etc/birdnet/birdnet.conf
fi

apprise_installation_status=$(~/BirdNET-Pi/birdnet/bin/python3 -c 'import pkgutil; print("installed" if pkgutil.find_loader("apprise") else "not installed")')
if [[ "$apprise_installation_status" = "not installed" ]];then
  $HOME/BirdNET-Pi/birdnet/bin/pip3 install -U pip
  $HOME/BirdNET-Pi/birdnet/bin/pip3 install apprise==1.6.0
fi
[ -f $HOME/BirdNET-Pi/apprise.txt ] || sudo -E -ucaddy touch $HOME/BirdNET-Pi/apprise.txt
if ! which lsof &>/dev/null;then
  sudo apt update && sudo apt -y install lsof
fi
if ! grep RTSP_STREAM /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "RTSP_STREAM=" >> /etc/birdnet/birdnet.conf
fi
if grep bash $HOME/BirdNET-Pi/templates/web_terminal.service &>/dev/null;then
  sudo sed -i '/User/d;s/bash/login/g' $HOME/BirdNET-Pi/templates/web_terminal.service
  sudo systemctl daemon-reload
  sudo systemctl restart web_terminal.service
fi
[ -L ~/BirdSongs/Extracted/static ] || ln -sf ~/BirdNET-Pi/homepage/static ~/BirdSongs/Extracted
if ! grep FLICKR_API_KEY /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "FLICKR_API_KEY=" >> /etc/birdnet/birdnet.conf
fi
if systemctl list-unit-files pushed_notifications.service &>/dev/null;then
  sudo systemctl disable --now pushed_notifications.service
  sudo rm -f /usr/lib/systemd/system/pushed_notifications.service
  sudo rm $HOME/BirdNET-Pi/templates/pushed_notifications.service
fi

if [ ! -f $HOME/BirdNET-Pi/model/labels.txt ];then
  [ $DATABASE_LANG == 'not-selected' ] && DATABASE_LANG=en
  $my_dir/install_language_label.sh -l $DATABASE_LANG \
  && logger "[$0] Installed new language label file for '$DATABASE_LANG'";
fi

if ! grep FLICKR_FILTER_EMAIL /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "FLICKR_FILTER_EMAIL=" >> /etc/birdnet/birdnet.conf
fi

pytest_installation_status=$(~/BirdNET-Pi/birdnet/bin/python3 -c 'import pkgutil; print("installed" if pkgutil.find_loader("pytest") else "not installed")')
if [[ "$pytest_installation_status" = "not installed" ]];then
  $HOME/BirdNET-Pi/birdnet/bin/pip3 install -U pip
  $HOME/BirdNET-Pi/birdnet/bin/pip3 install pytest==7.1.2 pytest-mock==3.7.0
fi

[ -L ~/BirdSongs/Extracted/weekly_report.php ] || ln -sf ~/BirdNET-Pi/scripts/weekly_report.php ~/BirdSongs/Extracted

if ! grep weekly_report /etc/crontab &>/dev/null;then
  sed "s/\$USER/$USER/g" $HOME/BirdNET-Pi/templates/weekly_report.cron | sudo tee -a /etc/crontab
fi
if ! grep APPRISE_WEEKLY_REPORT /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "APPRISE_WEEKLY_REPORT=1" >> /etc/birdnet/birdnet.conf
fi

if ! grep SILENCE_UPDATE_INDICATOR /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "SILENCE_UPDATE_INDICATOR=0" >> /etc/birdnet/birdnet.conf
fi

if ! grep '\-\-browser.gatherUsageStats false' $HOME/BirdNET-Pi/templates/birdnet_stats.service &>/dev/null ;then
  sudo -E sed -i "s|ExecStart=.*|ExecStart=$HOME/BirdNET-Pi/birdnet/bin/streamlit run $HOME/BirdNET-Pi/scripts/plotly_streamlit.py --browser.gatherUsageStats false --server.address localhost --server.baseUrlPath \"/stats\"|" $HOME/BirdNET-Pi/templates/birdnet_stats.service
  sudo systemctl daemon-reload && restart_services.sh
fi

# Make IceCast2 a little more secure
sudo sed -i.bak -e 's|<!-- <bind-address>.*|<bind-address>127.0.0.1</bind-address>|;s|<!-- <shoutcast-mount>.*|<shoutcast-mount>/stream</shoutcast-mount>|' /etc/icecast2/icecast.xml && if [ -s /etc/icecast2/icecast.xml.bak ] && ! sudo diff /etc/icecast2/icecast.xml /etc/icecast2/icecast.xml.bak > /dev/null; then sudo systemctl restart icecast2; fi

if ! grep FREQSHIFT_TOOL /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "FREQSHIFT_TOOL=sox" >> /etc/birdnet/birdnet.conf
fi

if ! grep SOX_SPEED /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "SOX_SPEED=0.1" >> /etc/birdnet/birdnet.conf
fi

if ! grep FREQSHIFT_HI /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "FREQSHIFT_HI=6000" >> /etc/birdnet/birdnet.conf
fi
if ! grep FREQSHIFT_LO /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "FREQSHIFT_LO=3000" >> /etc/birdnet/birdnet.conf
fi
if ! grep FREQSHIFT_PITCH /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "FREQSHIFT_PITCH=-1500" >> /etc/birdnet/birdnet.conf
fi
if ! grep ACTIVATE_FREQSHIFT_IN_LIVESTREAM /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "ACTIVATE_FREQSHIFT_IN_LIVESTREAM=\"false\"" >> /etc/birdnet/birdnet.conf
fi
if ! grep FREQSHIFT_RECONNECT_DELAY /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "FREQSHIFT_RECONNECT_DELAY=4000" >> /etc/birdnet/birdnet.conf
fi
if ! grep HEARTBEAT_URL /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "HEARTBEAT_URL=" >> /etc/birdnet/birdnet.conf
fi

if ! grep MODEL /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "MODEL=BirdNET_6K_GLOBAL_MODEL" >> /etc/birdnet/birdnet.conf
fi
if ! grep SF_THRESH /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "SF_THRESH=0.03" >> /etc/birdnet/birdnet.conf
fi
sudo chmod +x ~/BirdNET-Pi/scripts/install_language_label_nm.sh

sqlite3 $HOME/BirdNET-Pi/scripts/birds.db << EOF
CREATE INDEX IF NOT EXISTS "detections_Com_Name" ON "detections" ("Com_Name");
CREATE INDEX IF NOT EXISTS "detections_Date_Time" ON "detections" ("Date" DESC, "Time" DESC);
EOF

apprise_version=$($HOME/BirdNET-Pi/birdnet/bin/python3 -c "import apprise; print(apprise.__version__)")
streamlit_version=$($HOME/BirdNET-Pi/birdnet/bin/pip3 show streamlit 2>/dev/null | grep Version | awk '{print $2}')

[[ $apprise_version != "1.6.0" ]] && $HOME/BirdNET-Pi/birdnet/bin/pip3 install apprise==1.6.0
[[ $streamlit_version != "1.31.0" ]] && $HOME/BirdNET-Pi/birdnet/bin/pip3 install streamlit==1.19.0

if ! grep -q 'RuntimeMaxSec=' "$HOME/BirdNET-Pi/templates/birdnet_analysis.service"&>/dev/null; then
    sudo -E sed -i '/\[Service\]/a RuntimeMaxSec=900' "$HOME/BirdNET-Pi/templates/birdnet_analysis.service"
    sudo systemctl daemon-reload && restart_services.sh
fi

if ! grep RAW_SPECTROGRAM /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "RAW_SPECTROGRAM=0" >> /etc/birdnet/birdnet.conf
fi

if ! grep CUSTOM_IMAGE /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "CUSTOM_IMAGE=" >> /etc/birdnet/birdnet.conf
fi
if ! grep CUSTOM_IMAGE_TITLE /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "CUSTOM_IMAGE_TITLE=\"\"" >> /etc/birdnet/birdnet.conf
fi

if ! grep APPRISE_ONLY_NOTIFY_SPECIES_NAMES /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "APPRISE_ONLY_NOTIFY_SPECIES_NAMES=\"\"" >> /etc/birdnet/birdnet.conf
fi
if ! grep APPRISE_ONLY_NOTIFY_SPECIES_NAMES_2 /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "APPRISE_ONLY_NOTIFY_SPECIES_NAMES_2=\"\"" >> /etc/birdnet/birdnet.conf
fi

if ! grep RTSP_STREAM_TO_LIVESTREAM /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "RTSP_STREAM_TO_LIVESTREAM=\"0\"" >> /etc/birdnet/birdnet.conf
fi

suntime_installation_status=$(~/BirdNET-Pi/birdnet/bin/python3 -c 'import pkgutil; print("installed" if pkgutil.find_loader("suntime") else "not installed")')
if [[ "$suntime_installation_status" = "not installed" ]];then
  $HOME/BirdNET-Pi/birdnet/bin/pip3 install -U pip
  $HOME/BirdNET-Pi/birdnet/bin/pip3 install suntime
fi

# For new Advanced Setting Logging level options
if ! grep LogLevel_BirdnetRecordingService /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "LogLevel_BirdnetRecordingService=\"error\"" >> /etc/birdnet/birdnet.conf
fi

if ! grep LogLevel_LiveAudioStreamService /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "LogLevel_LiveAudioStreamService=\"error\"" >> /etc/birdnet/birdnet.conf
fi

if ! grep LogLevel_SpectrogramViewerService /etc/birdnet/birdnet.conf &>/dev/null;then
  sudo -u $USER echo "LogLevel_SpectrogramViewerService=\"error\"" >> /etc/birdnet/birdnet.conf
fi

if grep -q '^MODEL=BirdNET_GLOBAL_3K_V2.3_Model_FP16$' /etc/birdnet/birdnet.conf;then
  language=$(grep "^DATABASE_LANG=" /etc/birdnet/birdnet.conf | cut -d= -f2)
  sed -i 's/BirdNET_GLOBAL_3K_V2.3_Model_FP16/BirdNET_GLOBAL_6K_V2.4_Model_FP16/' /etc/birdnet/birdnet.conf
  sed -i 's/BirdNET_GLOBAL_3K_V2.3_Model_FP16/BirdNET_GLOBAL_6K_V2.4_Model_FP16/' $HOME/BirdNET-Pi/scripts/thisrun.txt
  sed -i 's/BirdNET_GLOBAL_3K_V2.3_Model_FP16/BirdNET_GLOBAL_6K_V2.4_Model_FP16/' $HOME/BirdNET-Pi/birdnet.conf
  cp -f $HOME/BirdNET-Pi/model/labels.txt $HOME/BirdNET-Pi/model/labels.txt.old
  sudo chmod +x $HOME/BirdNET-Pi/scripts/install_language_label_nm.sh && $HOME/BirdNET-Pi/scripts/install_language_label_nm.sh -l "$language"
fi

# if labels_flickr.txt doesnt exist, create it
labels_file="$HOME/BirdNET-Pi/model/labels_flickr.txt"
if [ ! -f "$labels_file" ]; then
    if [ -f "$HOME/BirdNET-Pi/scripts/thisrun.txt" ]; then
        config_file="$HOME/BirdNET-Pi/scripts/thisrun.txt"
    elif [ -f "$HOME/BirdNET-Pi/scripts/thisrun.ini" ]; then
        config_file="$HOME/BirdNET-Pi/scripts/thisrun.ini"
    fi

    language=$(grep -oP "^DATABASE_LANG\s*=\s*\K.*" "$config_file")
    model=$(grep -oP "^MODEL\s*=\s*\K.*" "$config_file")

    if [ "$model" == "BirdNET_GLOBAL_6K_V2.4_Model_FP16" ]; then
        chmod +x "$HOME/BirdNET-Pi/scripts/install_language_label_nm.sh"
        "$HOME/BirdNET-Pi/scripts/install_language_label_nm.sh" -l "$language"
    else
        "$HOME/BirdNET-Pi/scripts/install_language_label.sh" -l "$language"
    fi
fi


sudo systemctl daemon-reload
restart_services.sh
sudo systemctl restart batnet_timer_server.service
