#!/bin/bash
VER=3.4
#--[ Info ]-----------------------------------------------------
#
# This script comes without any warranty, use it at your own risk.
#
# Changelog
# 20XX-00-00 v1x Orginale creator Sokar aka PicdleRick
# 2020-10-20 v2x Code modifications and improvements Teqno/TeRRaNoVA
# 2020-10-23 v2.1 Changed the way languages are handled by Teqno
# 2020-10-24 v2.2 Added the ability to nuke shows based on rating by Teqno
# 2020-12-26 v2.3 Added the creation of blockfile for adaptive blocking in tur-predircheck by Teqno
# 2021-01-03 v2.4 Fixed format of adaptive blocking
# 2021-01-05 v2.5 Fixed check for previous blocks
# 2021-01-08 v2.6 Automatic sorting of adaptive blocklist
# 2021-01-26 v2.7 Fixed incorrect nuke when language is null
# 2021-03-03 v2.8 Added the ability to nuke shows based on status
# 2021-05-25 v2.9 Added the ability to nuke shows based on title 
# 2022-04-16 v3.0 Updated adaptive blocklist to put blocks in wide rows instead of one block per row to prevent problems of speed when creating new dirs
# 2022-04-21 v3.1 Added a cleanup option of adaptive blocklist based on the number of days for those sites that have a lot of blocks but that doesn't want them to 
#		  slow down the creation of new dirs
# 2024-02-17 v3.2 Fixed the cleanup function of adapative blocklist and added logging of cleanup to logfile  
# 2025-08-29 v3.3 Improved version with better error handling, performance optimizations, and safer variable usage.
# 2025-09-02 v3.4 Fixed the nuke_section_languages that got broken after latest optimization
#
# Installation: copy tvmaze-nuker.sh to glftpd/bin and chmod it
# 755. Copy the modificated TVMaze.tcl into your eggdrop pzs-ng
# plugins dir.
#
# Modify GLROOT into /glftpd or /jail/glftpd.
#
# To ensure log file exist, run: "./tvmaze-nuker.sh sanity" from
# shell, this will create the log file and set the correct
# permissions.
#
#--[ Settings ]-------------------------------------------------

GLROOT=/glftpd
GLCONF=$GLROOT/etc/glftpd.conf
DEBUG=0
LOG_FILE=$GLROOT/ftp-data/logs/tvmaze-nuker.log

# Username of person to nuke with. This user must be a glftpd user account.
NUKE_USER=glftpd

# Multiplier to use when nuking a release
NUKE_MULTIPLER=5

# Show Types: Animation Award_Show Documentary Game_Show News Panel_Show Reality Scripted Sports Talk_Show Variety
# Space delimited list of show types to nuke.
NUKE_SHOW_TYPES="Game_Show"

# Show Types: Animation Award_Show Documentary Game_Show News Panel_Show Reality Scripted Sports Talk_Show Variety
NUKE_SECTION_TYPES="
/site/TV-HD:(Sports|Award_Show|Game_Show)
"

# Configured like NUKE_SECTION_TYPES
# Genres: Action Adult Adventure Anime Children Comedy Crime DIY Drama Espionage Family Fantasy Food History Horror Legal Medical Music Mystery Nature Romance Science-Fiction 
# Sports Supernatural Thriller Travel War Western
NUKE_SECTION_GENRES="
/site/TV-HD:(Drama|Food|Music)
"

# Episodes with an air date before this year will be nuked
NUKE_EPS_BEFORE_YEAR="2018"

# Space delimited list of countries that will be nuked
NUKE_ORIGIN_COUNTRIES="DE"

# Space delimited list of Networks to nuke, remember to replace space with _ in Network names
NUKE_NETWORKS="CraveTV"

# Languages to NOT nuke.
NUKE_SECTION_LANGUAGES="
/site/TV-HD:(English)
"

# What rating should be the minimum *allowed* per section? For now, no decimals are allowed.
NUKE_SECTION_RATINGS="
/site/TV-HD:5
"

# Show Status: Running Ended To_Be_Determined In_Development
NUKE_SECTION_STATUS="
/site/TV-HD:(Ended)
"

# Space delimited list of Shows to nuke, use releasename and not show name ie use The.Flash and NOT The Flash
NUKE_SHOWS_LIST="The.Flash"

# 1 = Enable / 0 = Disable
NUKE_SHOW_TYPE=0
NUKE_SECTION_TYPE=0
NUKE_SECTION_GENRE=0
NUKE_EP_BEFORE_YEAR=0
NUKE_ORIGIN_COUNTRY=0
NUKE_NETWORK=0
NUKE_SECTION_LANGUAGE=0
NUKE_SECTION_RATING=0
NUKE_SECTION_STATS=0
NUKE_SHOW=0
NUKE_ADAPTIVE=0
NUKE_CLEAN_BLOCKLIST=0

# Space delimited list of TV shows to never nuke, use releasename and not show name ie use The.Flash and NOT The Flash
ALLOWED_SHOWS=""

# Space delimited list of Networks to never nuke, remember to replace space with _ in Network names
ALLOWED_NETWORKS=""

# Space delimited list of sections to never nuke
EXCLUDED_SECTIONS="ARCHIVE REQUEST"

# Space delimited list of groups to never nuke ie affils
EXCLUDED_GROUPS=""

# Blockfile for adaptive blocking that needs to be created and chmod 666
BLOCKFILE=$GLROOT/bin/tur-predircheck.block

# How many days should a row of blocks remain in BLOCKFILE before being cleaned out by the setting NUKE_CLEAN_BLOCKLIST
BLOCKDAYS=180 # 180 days = 6 months

# Length of rows in chars in BLOCKFILE. Its relevance is to the number of rows and blocks before losing speed when creating new dirs.
# WARNING: If you change this number you have to empty the file BLOCKFILE to avoid problems.
LENGTH=400

#--[ Script Start ]---------------------------------------------

LogMsg()
{

    DATE=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$DATE $@" >> $LOG_FILE

}

if [[ "$1" = "sanity" ]]
then

    echo
    echo "Creating log and blockfile and setting permission 666"
    touch $LOG_FILE && chmod 666 $LOG_FILE
    touch $BLOCKFILE && chmod 666 $BLOCKFILE
    exit 0

fi

if [[ ! -f $LOG_FILE ]]
then

    echo
    echo "Log file $LOG_FILE do not exist, create it by running ./tvmaze-nuker.sh sanity"
    echo
    exit 1

fi

if [[ ! -f $BLOCKFILE ]]
then

    echo
    echo "Blockfile $BLOCKFILE do not exist, create it by running ./tvmaze-nuker.sh sanity"
    echo
    exit 1

fi

if [[ $# -ne 9 ]]
then

    echo
    echo "ERROR! Missing arguments."
    echo
    LogMsg "ERROR! Not enough arguments passed in."
    exit 1

fi

# Process args and remove encapsulating double quotes.
remove_quotes() 
{
    printf '%s' "${1//\"/}"
}

RLS_NAME=$(remove_quotes "$1")
SHOW_GENRES=$(remove_quotes "$2")
SHOW_COUNTRY=$(remove_quotes "$3")
SHOW_LANGUAGE=$(remove_quotes "$4")
SHOW_NETWORK=$(remove_quotes "$5")
SHOW_STATUS=$(remove_quotes "$6")
SHOW_TYPE=$(remove_quotes "$7")
EP_AIR_DATE=$(remove_quotes "$8")
SHOW_RATING=$(remove_quotes "$9")

function addblock
{

today=$(date "+%Y-%m-%d")
section=$(echo $1 | cut -d '/' -f3)

if [[ ! "$(grep "$1" $BLOCKFILE)" ]]
then

    echo "$1:^($2)[._-]:$today" >> $BLOCKFILE

else

    if [ "$(grep "$1" $BLOCKFILE | tail -1 | wc -c)" -ge "$LENGTH" ]
    then

        $GLROOT/bin/sed -i -e "$(grep -n "/site/$section:^" $BLOCKFILE | tail -1 | cut -f1 -d':')a /site/$section:^($2)[._-]:$today" $BLOCKFILE

    else

        startword=$(grep "$1:^(" $BLOCKFILE | tail -1 | sed -e 's/\^(//' -e 's/)\[._-]//' | cut -d':' -f2 | cut -d'|' -f1)
        $GLROOT/bin/sed -i "/\/site\/$section:^(/ s/$startword/$2|$startword/" $BLOCKFILE

    fi

fi

}


if [[ "$DEBUG" == "1" ]]
then

    LogMsg "Release: $RLS_NAME Genres: $SHOW_GENRES Country: $SHOW_COUNTRY Language: $SHOW_LANGUAGE Network: $SHOW_NETWORK Status: $SHOW_STATUS Type: $SHOW_TYPE Air date: $EP_AIR_DATE Rating: $SHOW_RATING"

fi

for show in $ALLOWED_SHOWS
do

    result=$(echo "$RLS_NAME" | grep -i "$show")

    if [[ -n "$result" ]]
    then

        if [[ "$DEBUG" == "1" ]]
        then

            LogMsg "Skipping allowed show: $RLS_NAME"

        fi

        echo "Skipping allowed show: $RLS_NAME"
        exit 0

    fi

done

for network in $ALLOWED_NETWORKS
do

    result=$(echo "$SHOW_NETWORK" | grep -i "$network")

    if [[ -n "$result" ]]
    then

        if [[ "$DEBUG" == "1" ]]
        then

            LogMsg "Skipping allowed network: $RLS_NAME - $SHOW_NETWORK"

        fi

        echo "Skipping allowed network: $RLS_NAME - $SHOW_NETWORK"
        exit 0

    fi

done

for section in $EXCLUDED_SECTIONS
do

    result=$(echo "$RLS_NAME" | grep -i "$section/")

    if [[ -n "$result" ]]
    then

        if [[ "$DEBUG" == "1" ]]
        then

            LogMsg "Skipping excluded section: $RLS_NAME - $section"

        fi

        echo "Skipping excluded section: $RLS_NAME - $section"
        exit 0

    fi

done

for group in $EXCLUDED_GROUPS
do

    result=$(echo "$RLS_NAME" | grep -i "\-$group")

    if [[ -n "$result" ]]
    then

        if [[ "$DEBUG" == "1" ]]
        then

            LogMsg "Skipping excluded group: $RLS_NAME - $group"

        fi

        echo "Skipping excluded group: $RLS_NAME - $group"
        exit 0

    fi

done

if [[ "$NUKE_SHOW_TYPE" == "1" ]]
then

    if [[ -n "$NUKE_SHOW_TYPES" ]]
    then

        for type in $NUKE_SHOW_TYPES
        do

            if [[ "$SHOW_TYPE" == "$type" ]]
            then

                if [[ "$NUKE_ADAPTIVE" == "1" ]]
                then

		    		section=$(echo $RLS_NAME | cut -d'/' -f1-3)
                    exclude=$(echo $RLS_NAME | cut -d'/' -f4- | egrep -o ".S[0-9][0-9]E[0-9][0-9].*|.E[0-9][0-9].*|.[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}.*|.Part.[0-9].*")
                    block=$(echo $RLS_NAME | cut -d'/' -f4- | sed "s/$exclude//")
		    		[ ! $(grep "$section" $BLOCKFILE | grep "$block") ] && addblock $section $block

                fi

                $GLROOT/bin/nuker -r $GLCONF -N $NUKE_USER -n {$RLS_NAME} $NUKE_MULTIPLER "$type TV shows are not allowed"
                LogMsg "Nuked release: {$RLS_NAME} because its show type is $SHOW_TYPE which is not allowed."
                exit 0

            fi

        done

    fi

fi

if [[ "$NUKE_SECTION_TYPE" == "1" ]]
then

    for rawdata in $NUKE_SECTION_TYPES
    do

        section="$(echo "$rawdata" | cut -d ':' -f1)"
        denied="$(echo "$rawdata" | cut -d ':' -f2)"

        if echo "$RLS_NAME" | grep -iq "$section/"
        then

            if echo "$SHOW_TYPE" | grep -Eiq "$denied"
            then

        		type="$(echo $SHOW_TYPE | grep -Eoi $denied)"

                if [[ "$NUKE_ADAPTIVE" == "1" ]]
                then

                    exclude=$(echo $RLS_NAME | cut -d'/' -f4- | egrep -o ".S[0-9][0-9]E[0-9][0-9].*|.E[0-9][0-9].*|.[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}.*|.Part.[0-9].*")
                    block=$(echo $RLS_NAME | cut -d'/' -f4- | sed "s/$exclude//")
		    		[ ! $(grep "$section" $BLOCKFILE | grep "$block") ] && addblock $section $block

                fi

                $GLROOT/bin/nuker -r $GLCONF -N $NUKE_USER -n {$RLS_NAME} $NUKE_MULTIPLER "$type type of TV show is not allowed"
                LogMsg "Nuked release: {$RLS_NAME} because its show type is $type which is not allowed in section $section."
                exit 0

            fi

        fi

    done

fi

if [[ "$NUKE_SECTION_GENRE" == "1" ]]
then

    for rawdata in $NUKE_SECTION_GENRES
    do

        section="$(echo "$rawdata" | cut -d ':' -f1)"
        denied="$(echo "$rawdata" | cut -d ':' -f2)"

        if echo "$RLS_NAME" | grep -iq "$section/"
        then

            if echo "$SHOW_GENRES" | grep -Eiq "$denied"
            then

                genre="$(echo $SHOW_GENRES | grep -Eoi $denied)"

                if [[ "$NUKE_ADAPTIVE" == "1" ]]
                then

                    exclude=$(echo $RLS_NAME | cut -d'/' -f4- | egrep -o ".S[0-9][0-9]E[0-9][0-9].*|.E[0-9][0-9].*|.[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}.*|.Part.[0-9].*")
                    block=$(echo $RLS_NAME | cut -d'/' -f4- | sed "s/$exclude//")
		    		[ ! $(grep "$section" $BLOCKFILE | grep "$block") ] && addblock $section $block

                fi

                $GLROOT/bin/nuker -r $GLCONF -N $NUKE_USER -n {$RLS_NAME} $NUKE_MULTIPLER "$genre genre is not allowed"
                LogMsg "Nuked release: {$RLS_NAME} because its genre is $genre which is not allowed in section $section."
                exit 0

            fi

        fi

    done

fi

if [[ "$NUKE_EP_BEFORE_YEAR" == "1" && -n "$EP_AIR_DATE" && "$EP_AIR_DATE" != "N/A" ]]
then

    ep_air_year=$(date +"%Y" -d "$EP_AIR_DATE" 2>/dev/null)
    
    if [[ -n "$ep_air_year" && "$ep_air_year" -lt "${NUKE_EPS_BEFORE_YEAR:-0}" ]]
    then
    
        if [[ "$NUKE_ADAPTIVE" == "1" ]]
        then
        
            section=$(echo "$RLS_NAME" | cut -d'/' -f1-3)
            exclude=$(echo "$RLS_NAME" | cut -d'/' -f4- | grep -Eo ".S[0-9][0-9]E[0-9][0-9].*|.E[0-9][0-9].*|.[0-9]{4}.[0-9]{2}.[0-9]{2}.*|.Part.[0-9].*")
            block=$(echo "$RLS_NAME" | cut -d'/' -f4- | sed "s/$exclude//")
            
            if ! grep -q "$section" "$BLOCKFILE" | grep -q "$block"
            then
            
                addblock "$section" "$block"
            
            fi

        fi

        $GLROOT/bin/nuker -r "$GLCONF" -N "$NUKE_USER" -n "${RLS_NAME}" "$NUKE_MULTIPLER" "Episode air date must be $NUKE_EPS_BEFORE_YEAR or newer"
        LogMsg "Nuked release: ${RLS_NAME} because its year of release of $ep_air_year is before $NUKE_EPS_BEFORE_YEAR"
        exit 0

    fi

fi


if [[ "$NUKE_ORIGIN_COUNTRY" == "1" ]]
then

    if [[ -n "$NUKE_ORIGIN_COUNTRIES" ]]
    then

        for country in $NUKE_ORIGIN_COUNTRIES
        do

            if [[ "$SHOW_COUNTRY" == "$country" ]]
            then

    			if [[ "$NUKE_ADAPTIVE" == "1" ]]
            	then

		    		section=$(echo $RLS_NAME | cut -d'/' -f1-3)
            	    exclude=$(echo $RLS_NAME | cut -d'/' -f4- | egrep -o ".S[0-9][0-9]E[0-9][0-9].*|.E[0-9][0-9].*|.[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}.*|.Part.[0-9].*")
            	    block=$(echo $RLS_NAME | cut -d'/' -f4- | sed "s/$exclude//")
		    		[ ! $(grep "$section" $BLOCKFILE | grep "$block") ] && addblock $section $block

            	fi

                $GLROOT/bin/nuker -r $GLCONF -N $NUKE_USER -n {$RLS_NAME} $NUKE_MULTIPLER "TV shows from $country are not allowed"
                LogMsg "Nuked release: {$RLS_NAME} because its country of origin is $SHOW_COUNTRY which is not allowed."
                exit 0

            fi

        done

    fi

fi

if [[ "$NUKE_NETWORK" == "1" ]]
then

    if [[ -n "$NUKE_NETWORKS" ]]
    then

        for network in $NUKE_NETWORKS
        do

            if [[ "$SHOW_NETWORK" == "$network" ]]
            then

                if [[ "$NUKE_ADAPTIVE" == "1" ]]
                then

                    section=$(echo "$RLS_NAME" | cut -d'/' -f1-3)
                    exclude=$(echo "$RLS_NAME" | cut -d'/' -f4- | grep -Eo ".S[0-9][0-9]E[0-9][0-9].*|.E[0-9][0-9].*|.[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}.*|.Part.[0-9].*")
                    block=$(echo "$RLS_NAME" | cut -d'/' -f4- | sed "s/$exclude//")
                    
                    if ! grep -q "$section" "$BLOCKFILE" && grep -q "$block" "$BLOCKFILE"
                    then
                    
						addblock "$section" "$block"
                
					fi
				
                fi

                $GLROOT/bin/nuker -r "$GLCONF" -N "$NUKE_USER" -n "${RLS_NAME}" "$NUKE_MULTIPLER" "Network $network is not allowed"
                LogMsg "Nuked release: ${RLS_NAME} because its network is $SHOW_NETWORK which is not allowed."
                exit 0

            fi

        done

    fi

fi

if [[ "$NUKE_SECTION_LANGUAGE" == "1" ]]
then

    for rawdata in $NUKE_SECTION_LANGUAGES
    do

        section="$(echo "$rawdata" | cut -d ':' -f1)"
        allowed="$(echo "$rawdata" | cut -d ':' -f2)"

        if echo "$RLS_NAME" | grep -iq "$section/"
        then

            if ! echo "$SHOW_LANGUAGE" | grep -Eiq "$allowed"
            then

                [[ "$SHOW_LANGUAGE" == "null" ]] && exit 0

                if [[ "$NUKE_ADAPTIVE" == "1" ]]
                then

                    exclude=$(echo "$RLS_NAME" | cut -d'/' -f4- | grep -Eo ".S[0-9][0-9]E[0-9][0-9].*|.E[0-9][0-9].*|.[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}.*|.Part.[0-9].*")
                    block=$(echo "$RLS_NAME" | cut -d'/' -f4- | sed "s/$exclude//")
                    
                    if ! grep -q "$section" "$BLOCKFILE" || ! grep -q "$block" "$BLOCKFILE"
                    then
                 
						addblock "$section" "$block"
                    
					fi

                fi

                "$GLROOT/bin/nuker" -r "$GLCONF" -N "$NUKE_USER" -n "$RLS_NAME" "$NUKE_MULTIPLER" "Language $SHOW_LANGUAGE is not allowed"
                LogMsg "Nuked release: $RLS_NAME because its language is $SHOW_LANGUAGE which is not allowed in section $section."
                exit 0

            fi

        fi

    done

fi

if [[ "$NUKE_SECTION_RATING" == "1" ]]
then

    for rawdata in $NUKE_SECTION_RATINGS
    do

        section="$(echo "$rawdata" | cut -d ':' -f1)"
        limit="$(echo "$rawdata" | cut -d ':' -f2)"
        rating="$(echo "$SHOW_RATING" | awk '{print int($1)}')"

        if echo "$RLS_NAME" | grep -iq "$section/"
        then

            if [[ -n "$SHOW_RATING" ]] && [[ "$rating" -lt "$limit" ]]
            then

                if [[ "$NUKE_ADAPTIVE" == "1" ]]
                then

                    exclude=$(echo "$RLS_NAME" | cut -d'/' -f4- | grep -Eo ".S[0-9][0-9]E[0-9][0-9].*|.E[0-9][0-9].*|.[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}.*|.Part.[0-9].*")
                    block=$(echo "$RLS_NAME" | cut -d'/' -f4- | sed "s/$exclude//")
                    
                    if ! grep -q "$section" "$BLOCKFILE" || ! grep -q "$block" "$BLOCKFILE"
                    then
                        
						addblock "$section" "$block"
                    
					fi

                fi

                "$GLROOT/bin/nuker" -r "$GLCONF" -N "$NUKE_USER" -n "$RLS_NAME" "$NUKE_MULTIPLER" "Rating $SHOW_RATING is below the limit of $limit"
                LogMsg "Nuked release: $RLS_NAME because its rating $SHOW_RATING is below the limit of $limit for section $section."
                exit 0

            fi

        fi

    done

fi

if [[ "$NUKE_SECTION_STATS" == "1" ]]
then

    for rawdata in $NUKE_SECTION_STATUS
    do

        section="$(echo "$rawdata" | cut -d ':' -f1)"
        denied="$(echo "$rawdata" | cut -d ':' -f2)"

        if echo "$RLS_NAME" | grep -iq "$section/"
        then

            if ! echo "$SHOW_STATUS" | grep -iq "$denied"
            then

                [[ "$SHOW_STATUS" == "null" ]] && exit 0

                if [[ "$NUKE_ADAPTIVE" == "1" ]]
                then

                    exclude=$(echo "$RLS_NAME" | cut -d'/' -f4- | grep -Eo ".S[0-9][0-9]E[0-9][0-9].*|.E[0-9][0-9].*|.[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}.*|.Part.[0-9].*")
                    block=$(echo "$RLS_NAME" | cut -d'/' -f4- | sed "s/$exclude//")
                    
                    if ! grep -q "$section" "$BLOCKFILE" || ! grep -q "$block" "$BLOCKFILE"
                    then
                        
						addblock "$section" "$block"
                    
					fi

                fi

                "$GLROOT/bin/nuker" -r "$GLCONF" -N "$NUKE_USER" -n "$RLS_NAME" "$NUKE_MULTIPLER" "The status of show is $SHOW_STATUS which is not allowed"
                LogMsg "Nuked release: $RLS_NAME because its status is $SHOW_STATUS which is not allowed in section $section."
                exit 0

            fi

        fi

    done

fi

if [[ "$NUKE_SHOW" == "1" ]]
then

    if [[ -n "$NUKE_SHOWS_LIST" ]]
    then

        for title in $NUKE_SHOWS_LIST
        do

            if echo "$RLS_NAME" | grep -iq "$title"
            then

                "$GLROOT/bin/nuker" -r "$GLCONF" -N "$NUKE_USER" -n "$RLS_NAME" "$NUKE_MULTIPLER" "show not allowed"
                LogMsg "Nuked release: $RLS_NAME because show is not allowed."
                exit 0

            fi

        done

    fi

fi

if [[ "$NUKE_CLEAN_BLOCKLIST" -eq 1 ]]
then

    current_epoch=$(date +%s)
    declare -A seen
    to_delete=()

    while IFS= read -r row
    do

        blockdate=$(echo "$row" | cut -d ':' -f3)

        # Skip invalid dates
        if ! date --date "$blockdate" &>/dev/null
        then

            continue

        fi

        block_epoch=$(date +%s --date "$blockdate")
        days=$(( (current_epoch - block_epoch) / 86400 ))

        if [[ "$days" -ge "$BLOCKDAYS" ]]
        then

            LogMsg "Automatic removal of blocks with date $blockdate"

            if [[ -z "${seen[$blockdate]}" ]]
            then

                to_delete+=( "$blockdate" )
                seen[$blockdate]=1

            fi

        fi

    done < "$BLOCKFILE"

    if (( ${#to_delete[@]} > 0 ))
    then

        sed_script=
        for d in "${to_delete[@]}"
        do

            sed_script+="/$d/d;"

        done

        "$GLROOT/bin/sed" -i -e "$sed_script" "$BLOCKFILE"

    fi

fi

