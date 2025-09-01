#!/bin/bash
VER=1.3
#--[ Info ]-----------------------------------------------------
#                                                               
# Section Traffic by Teqno                                      
#                                                               
# This script requires the use of xferlog-import to work. It    
# shows the up / down / total stats for sections on site.       
#                                                               
#-[ Install ]---------------------------------------------------
#                                                               
# Copy this script to $GLROOT/bin and chmod it 755. Go through  
# the settings and ensure they are correct. If you change       
# trigger then ensure that it is the same as in tcl script. To  
# ensure that stats are up to date you have to run the import   
# script in crontab. Again, go over the settings and ensure     
# they are correct. My suggestion is to run the import script   
# every 30 min in crontab and run a daily cleanup to ensure db  
# only has the releases that are on site. Put these in crontab. 
#                                                               
# */30 * * * *    $GLROOT/bin/xferlog-import_3.3.sh             
# 30 0 * * *      $GLROOT/bin/section-traffic.sh cleanup        
#                                                               
#--[ Settings ]-------------------------------------------------

GLROOT=/glftpd
TMP=$GLROOT/tmp

SQLBIN="mysql"
SQLHOST="localhost"
SQLUSER="transfer"
SQLPASS=""
SQLDB="transfers"
SQLTB="changeme"
SQL="$SQLBIN -P 3307 --ssl=0 -u $SQLUSER -p"$SQLPASS" -h $SQLHOST -D $SQLDB -N -s"
SQLEXPIRE="6"

COLOR1="4"
COLOR2="14"
COLOR3="7"
BOLD=""

EXCLUDED="PRE|SPEEDTEST|lost\+found|Search_Links|ARCHIVE.EXP|INCOMING|INCOMPLETES|MUSIC.BY.ARTIST|MUSIC.BY.GENRE|!Today_0DAY|!Today_FLAC|!Today_MP3|MOVIES_SORTED"

TRIGGER=$(grep "bind pub" $GLROOT/sitebot/scripts/section-traffic.tcl | cut -d " " -f4)

#--[ Script start ]---------------------------------------------

if [[ "$(stat -c "%a" $TMP)" != 777 ]]
then

    echo "$TMP folder not writeable, do chmod 777 $TMP"
    exit 1

fi

ARGS=$(echo "$@" | cut -d ' ' -f2-)

if [[ "$ARGS" = "help" ]]
then

    cat <<-EOF
	${COLOR2}Run without argument to show stats for current month.
	${COLOR2}To check another month: ${COLOR1}$TRIGGER 2020-08
	${COLOR2}To check a specific user: ${COLOR1}$TRIGGER user <username>
	${COLOR2}To check a specific user and month: ${COLOR1}$TRIGGER user <username> month 2020-08
	${COLOR2}To check the top 10 downloaded releases for current month: ${COLOR1}$TRIGGER top
	${COLOR2}To check the top 10 downloaded releases for specific month: ${COLOR1}$TRIGGER top month 2020-08
	${COLOR2}To check the top 30 downloaded releases for current month: ${COLOR1}$TRIGGER top 30
	${COLOR2}To check the top 30 downloaded releases for specific month: ${COLOR1}$TRIGGER top month 2020-08 30
	${COLOR2}To check stats for specific release: ${COLOR1}$TRIGGER release <releasename> <username>
	EOF

    exit 0

fi

if [[ "$ARGS" = "cleanup" ]]
then

    for cleanup in $($SQL -e "select distinct section FROM $SQLTB")
    do

        if [[ ! -d $GLROOT/site/$cleanup ]]
        then

            echo "Removing data for section $cleanup since it no longer exist on site"
            $SQL -e "delete from $SQLTB where section='$cleanup'"
            echo "Done"

        fi

    done

    echo "Removing data older than $SQLEXPIRE months from db"
    $SQL -e "delete from $SQLTB where datetime < now() - interval $SQLEXPIRE month"
    echo "Done"

    exit 0

fi

tunit=GB
iunit=GB
ounit=GB

if [[ "$ARGS" = "release"* ]]
then

    release=$(echo $ARGS | cut -d ' ' -f2)
    username=$(echo $ARGS | cut -d ' ' -f3)
    echo "${COLOR2}Stats for release${COLOR1} $release ${COLOR2}for user${COLOR1} $username"
    query=$($SQL -e "SELECT
			ROUND(SUM(bytes / 1024 / 1024 / 1024), 2) AS traffic,
			ROUND(SUM(CASE WHEN direction = 'i' THEN bytes / 1024 / 1024 / 1024 ELSE 0 END), 2) AS incoming,
			ROUND(SUM(CASE WHEN direction = 'o' THEN bytes / 1024 / 1024 / 1024 ELSE 0 END), 2) AS outgoing,
			COUNT(CASE WHEN direction = 'i' THEN id END) AS filesinc,
			COUNT(CASE WHEN direction = 'o' THEN id END) AS filesout
		    FROM
			$SQLTB
		    WHERE
			relname = '$release'
		    AND 
			FTPuser = '$username'")

    echo $query | while read -r traffic incoming outgoing filesinc filesout;
    do

        for var in traffic incoming outgoing filesinc filesout
        do

            val="${!var-}"
            if [[ -z "$val" || "${val,,}" == "null" ]]
            then

                if [[ "$var" == "filesinc" || "$var" == "filesout" ]]
                then

                    printf -v "$var" '%s' "No files"

                else

                    printf -v "$var" '%s' 0

                fi

            fi

        done


        if [[ $(echo $traffic | cut -d'.' -f1) -gt 1024 ]]
        then

            rawtraffic=$(echo "$traffic / 1024" | bc -l)
            firstnum=$(echo $rawtraffic | cut -d'.' -f1)
            secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
            traffic="$firstnum.$secondnum"
            tunit=TB

        fi

        if [[ $(echo $incoming | cut -d'.' -f1) -gt 1024 ]]
        then

            rawtraffic=$(echo "$incoming / 1024" | bc -l)
            firstnum=$(echo $rawtraffic | cut -d'.' -f1)
            secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
            incoming="$firstnum.$secondnum"
            iunit=TB

        fi

        if [[ $(echo $outgoing | cut -d'.' -f1) -gt 1024 ]]
        then
            rawtraffic=$(echo "$outgoing / 1024" | bc -l)
            firstnum=$(echo $rawtraffic | cut -d'.' -f1)
            secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
            outgoing="$firstnum.$secondnum"
            ounit=TB
	fi

        echo "${COLOR2}Up:${COLOR1} ${incoming} ${COLOR2}$iunit - Down:${COLOR1} ${outgoing} ${COLOR2}$ounit - Total:${COLOR1} ${traffic} ${COLOR2}$tunit - Files Incoming:${COLOR1} ${filesinc} ${COLOR2} - Files Outgoing: ${COLOR1} ${filesout}"

    done	

    echo "${COLOR3}The statistics have a 30 min delay"
    exit 0

fi

if [[ "$ARGS" = "user"* ]]
then

    if [[ "$(echo $ARGS | cut -d ' ' -f3)" != "month" ]]
    then

	month=$(date +%Y-%m)

    else

	month=$(echo $ARGS | cut -d ' ' -f4)

    fi

    username=$(echo $ARGS | cut -d ' ' -f2)

    echo "${COLOR2}Section stats for${COLOR1} $month ${COLOR2}on${COLOR1} $SQLTB ${COLOR2}for user${COLOR1} $username"

    for section in $(ls $GLROOT/site | egrep -v "$EXCLUDED" | sed '/^\s*$/d')
    do

        query=$($SQL -e "SELECT
			    ROUND(SUM(bytes / 1024 / 1024 / 1024), 2) AS traffic,
		    	    ROUND(SUM(CASE WHEN direction = 'i' THEN bytes / 1024 / 1024 / 1024 ELSE 0 END), 2) AS incoming,
		    	    ROUND(SUM(CASE WHEN direction = 'o' THEN bytes / 1024 / 1024 / 1024 ELSE 0 END), 2) AS outgoing,
		    	    MAX(CASE WHEN direction = 'i' THEN datetime END) AS lastup
			FROM
		    	    $SQLTB
			WHERE
		    	    section = '$section'
		    	AND 
		    	    datetime LIKE '$month%'
		        AND 
		    	    FTPuser = '$username'")

	echo $query | while read -r traffic incoming outgoing lastup;
	do

    	    for var in traffic incoming outgoing lastup
    	    do

        	val="${!var}"
        	if [[ -z "$val" || "${val,,}" == "null" ]]
        	then

            	    if [[ "$var" == "lastup" ]]
            	    then

                	printf -v "$var" '%s' "No upload"

            	    else

                	printf -v "$var" '%s' 0

            	    fi

        	fi

    	    done

    
	    if [[ $(echo $traffic | cut -d'.' -f1) -gt 1024 ]]
	    then
		rawtraffic=$(echo "$traffic / 1024" | bc -l)
		firstnum=$(echo $rawtraffic | cut -d'.' -f1)
		secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
		traffic="$firstnum.$secondnum"
		tunit=TB
	    fi
    
	    if [[ $(echo $incoming | cut -d'.' -f1) -gt 1024 ]]
	    then
		rawtraffic=$(echo "$incoming / 1024" | bc -l)
		firstnum=$(echo $rawtraffic | cut -d'.' -f1)
		secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
		incoming="$firstnum.$secondnum"
		iunit=TB
	    fi
    
	    if [[ $(echo $outgoing | cut -d'.' -f1) -gt 1024 ]]
	    then
		rawtraffic=$(echo "$outgoing / 1024" | bc -l)
		firstnum=$(echo $rawtraffic | cut -d'.' -f1)
		secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
		outgoing="$firstnum.$secondnum"
		ounit=TB
	    fi	

	    echo "${COLOR2}Section:${COLOR1} $section ${COLOR2}- Up:${COLOR1} ${incoming} ${COLOR2}$iunit - Down:${COLOR1} ${outgoing} ${COLOR2}$ounit - Total:${COLOR1} ${traffic} ${COLOR2}$tunit - Last upload:${COLOR1} ${lastup}"

	done

    done

    echo "${COLOR3}The statistics have a 30 min delay"
    exit 0

fi

if [[ "$ARGS" = "top"* ]]
then

    if [[ "$(echo $ARGS | cut -d ' ' -f2)" != "month" ]]
    then

	if [[ "$(echo $ARGS | cut -d ' ' -f2)" =~ ^-?[0-9]+$ ]]
	then

	    if [[ "$(echo $ARGS | cut -d ' ' -f2)" -le "30" ]]
	    then

		topres=$(echo $ARGS | cut -d ' ' -f2)

	    else

		echo "Not allowed to check for more than 30 top releases"
		exit 0

	    fi

	else

	    topres=10

	fi

        month=$(date +%Y-%m)

    else

        if [[ "$(echo $ARGS | cut -d ' ' -f4)" =~ ^-?[0-9]+$ ]]
        then

            if [[ "$(echo $ARGS | cut -d ' ' -f4)" -le "30" ]]
            then

                topres=$(echo $ARGS | cut -d ' ' -f4)

            else

                echo "Not allowed to check for more than 30 top releases"
                exit 0

            fi

        else

            topres=10

        fi

        month=$(echo $ARGS | cut -d ' ' -f3)

    fi

    query=$($SQL -t -e "SELECT relname, section, count(*) as download FROM $SQLTB where datetime like '$month%' and direction='o' group by relname order by download desc limit $topres")
    i=1
    echo "${COLOR2}Top $topres downloaded releases for${COLOR1} $month"
    echo $query > $TMP/section-traffic.tmp
    cat $TMP/section-traffic.tmp | tr -s "-" | sed -e 's|+-+-+-+||g' -e 's/| |/\n/g' -e 's/^ | //' -e 's/ //g' -e 's/|$//' > $TMP/section-traffic2.tmp

    for rel in $(cat $TMP/section-traffic2.tmp)
    do

	position="$((i++))"
	position=$(printf "%2.0d\n" $position |sed "s/ /0/")
	relname=$(echo $rel | cut -d'|' -f1)
	section=$(echo $rel | cut -d'|' -f2)
	download=$(echo $rel | cut -d'|' -f3)
	echo "${BOLD}$position${BOLD}.${COLOR1} ${relname} ${COLOR2}- Section:${COLOR1} $section ${COLOR2}- Files:${COLOR1} ${download}"

    done

    rm $TMP/section-traffic*
    echo "${COLOR3}The statistics have a 30 min delay"

    exit 0    

fi

if [[ -z "$ARGS" ]]
then

    month=$(date +%Y-%m)

else

    month=$ARGS

fi

echo "${COLOR2}Section stats for${COLOR1} $month ${COLOR2}on${COLOR1} $SQLTB"

for section in $(ls $GLROOT/site | egrep -v "$EXCLUDED" | sed '/^\s*$/d')
do

    query=$($SQL -e "SELECT
			ROUND(SUM(bytes / 1024 / 1024 / 1024), 2) AS traffic,
			ROUND(SUM(CASE WHEN direction = 'i' THEN bytes / 1024 / 1024 / 1024 ELSE 0 END), 2) AS incoming,
			ROUND(SUM(CASE WHEN direction = 'o' THEN bytes / 1024 / 1024 / 1024 ELSE 0 END), 2) AS outgoing,
			MAX(CASE WHEN direction = 'i' THEN datetime END) AS lastup
		    FROM
			$SQLTB
		    WHERE
			section = '$section'
		    AND 
			datetime LIKE '$month%'")

    if [[ -z "$query" ]]
    then

        echo "${COLOR3}No data in db"
        exit 0

    fi

    echo $query | while read -r traffic incoming outgoing lastup;
    do

        for var in traffic incoming outgoing lastup
        do

            val="${!var}"
            if [[ -z "$val" || "${val,,}" == "null" ]]
            then

                if [[ "$var" == "lastup" ]]
                then

                    printf -v "$var" '%s' "No upload"

                else

                    printf -v "$var" '%s' 0

                fi

            fi

        done


	if [[ $(echo $traffic | cut -d'.' -f1) -gt 1024 ]]
	then

	    rawtraffic=$(echo "$traffic / 1024" | bc -l)
	    firstnum=$(echo $rawtraffic | cut -d'.' -f1)
	    secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
	    traffic="$firstnum.$secondnum"
	    tunit=TB

	fi

	if [[ $(echo $incoming | cut -d'.' -f1) -gt 1024 ]]
	then

	    rawtraffic=$(echo "$incoming / 1024" | bc -l)
	    firstnum=$(echo $rawtraffic | cut -d'.' -f1)
	    secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
	    incoming="$firstnum.$secondnum"
	    iunit=TB

	fi

	if [[ $(echo $outgoing | cut -d'.' -f1) -gt 1024 ]]
	then

	    rawtraffic=$(echo "$outgoing / 1024" | bc -l)
	    firstnum=$(echo $rawtraffic | cut -d'.' -f1)
	    secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
	    outgoing="$firstnum.$secondnum"
	    ounit=TB

	fi

        echo "${COLOR2}Section:${COLOR1} $section ${COLOR2}- Up:${COLOR1} ${incoming} ${COLOR2}$iunit - Down:${COLOR1} ${outgoing} ${COLOR2}$ounit - Total:${COLOR1} ${traffic} ${COLOR2}$tunit - Last upload:${COLOR1} ${lastup}"

    done

done

query=$($SQL -e "SELECT
		ROUND(SUM(bytes / 1024 / 1024 / 1024), 2) AS traffic,
	        ROUND(SUM(CASE WHEN direction = 'i' THEN bytes / 1024 / 1024 / 1024 ELSE 0 END), 2) AS incoming,
	        ROUND(SUM(CASE WHEN direction = 'o' THEN bytes / 1024 / 1024 / 1024 ELSE 0 END), 2) AS outgoing,
	        MAX(CASE WHEN direction = 'i' THEN datetime END) AS lastup
		FROM
	        $SQLTB
		WHERE
	        datetime LIKE '$month%'")

echo $query | while read -r traffic incoming outgoing lastup;
do

    for var in traffic incoming outgoing lastup
    do

        val="${!var}"
        if [[ -z "$val" || "${val,,}" == "null" ]]
        then

            if [[ "$var" == "lastup" ]]
            then

                printf -v "$var" '%s' "No upload"

            else

                printf -v "$var" '%s' 0

            fi

        fi

    done


    if [[ $(echo $traffic | cut -d'.' -f1) -gt 1024 ]]
    then

        rawtraffic=$(echo "$traffic / 1024" | bc -l)
	firstnum=$(echo $rawtraffic | cut -d'.' -f1)
        secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
	traffic="$firstnum.$secondnum"
        tunit=TB

    fi

    if [[ $(echo $incoming | cut -d'.' -f1) -gt 1024 ]]
    then

	rawtraffic=$(echo "$incoming / 1024" | bc -l)
        firstnum=$(echo $rawtraffic | cut -d'.' -f1)
	secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
        incoming="$firstnum.$secondnum"
	iunit=TB
    fi

    if [[ $(echo $outgoing | cut -d'.' -f1) -gt 1024 ]]
    then

	rawtraffic=$(echo "$outgoing / 1024" | bc -l)
        firstnum=$(echo $rawtraffic | cut -d'.' -f1)
	secondnum=$(echo $rawtraffic | cut -d'.' -f2 | cut -b1-2)
        outgoing="$firstnum.$secondnum"
        ounit=TB
    fi

    echo "${COLOR1}All Sections${COLOR2} - Up:${COLOR1} ${incoming} ${COLOR2}$iunit - Down:${COLOR1} ${outgoing} ${COLOR2}$ounit - Total:${COLOR1} ${traffic} ${COLOR2}$tunit - Last upload:${COLOR1} ${lastup}"

done

echo "${COLOR3}The statistics have a 30 min delay"
