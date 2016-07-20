#!/bin/bash
################################################################################
#
#   Filename: bb-installer-prep-helper.sh
#   Created By: Huy Nguyen
#   Email: huy.nguyen@blackboard.com
#   GIT: https://github.com/huynguyenbb
#   Description: Run this script to assist in generating a properties file
#   for Q2 2016 and above Learn Releases to perform Installs/Upgrades
#
################################################################################

# BBHOME default, /usr/local/blackboard
BBHOME=/usr/local/blackboard
# Location of bb-config.properties file, will be based on BBHOME directory
BBCONFIG=${BBHOME}/config/bb-config.properties
# installer.properties Parameters Array
CONFIGPARAMETERS=()

# ` file default location
INSTALLERPROPFILENAME="installer.properties"
INSTALLERPROP=$(pwd)/${INSTALLERPROPFILENAME}

# Some Defaults

# Learn is SSL enforced, so no reason to ask Users to manually specify these parameters
FRONTENDPROTOCOL="https"
FRONTENDPORT=443
ORACLEDEFAULTPORT=1521
SQLDEFAULTPORT=1433
# Setting the default to Oracle, since this is a Shell Script
DBDEFAULTPORT=${ORACLEDEFAULTPORT}

DBTYPE="oracle"                     # can only be oracle or mssql, since this is a shell script we're going to assume oracle
DBINSTNAMETYPE="SID"                # Database Name type, will be SID by default, SERVICE_NAME may be an option, but I don't know if that may work
DBDRIVETYPE="thin"                  # Oracle Drivers, will be default thin instead of oci as we're assuming non clustered DB.



# Determine BBHOME, wether fresh or exisiting
function getBBHome() {

    unset CONTINUE
    unset GOWITHDEFAULT
    unset NEWBBHOME

    # Does bb-config.properties exisiting within default Learn directory?
    if [ -f "${BBCONFIG}" ]; then

        echo "BLACKBOARD Home found at ${BBHOME}!"

        # Local installation found, should we upgrade?
        while [[ -z "${CONTINUE}" ]] || [[ "$(echo ${CONTINUE} | grep -ic 'y\|n')" -eq 0 ]]; do
            read -p "Do you want to use that as your BLACKBOARD_HOME Path and create an Upgrader config? [y/N]: " CONTINUE
        done
    else

        echo "BLACKBOARD Home not found!"

        while [ -z "${GOWITHDEFAULT}" ]; do
            read -p "Go with default Location ${BBHOME}? [y/N]: " GOWITHDEFAULT
        done
    fi

    # Do we specify new BBHOME?
    if [[ "$(echo ${GOWITHDEFAULT} | grep -ic 'n')" -eq 1 ]] || [[ "$(echo ${CONTINUE} | grep -ic 'n')" -eq 1 ]]; then
        while [[ -z "${NEWBBHOME}" ]]; do
            read -p "Enter new Location for BLACKBOARD_HOME [i.e. ${BBHOME}]: " NEWBBHOME
        done

        # SET BBHOME = NEWBBHOME
        BBHOME=${NEWBBHOME}
        echo "BBHOME Now set to ${BBHOME}!"
    fi
}


function configureFreshInstall() {

    unset INSTALLOPTION
    unset SHAREDCONTENTLOC
    unset LICENSEFILE
    unset COPYLICENSE
    unset JDKPATH
    unset APPSERVERFULLHOSTNAME
    unset APPSERVERMACHINENAME
    unset SMTPHOSTNAME
    unset FRONTENDHOSTNAME
    unset DBHOSTNAME
    unset DBTYPECHOICE
    unset DBTYPE
    unset DBPORT
    unset DBINSTNAMETYPE
    unset DBINSTNAME
    unset DBSYSPASSWD
    unset DBDATADIR
    unset DBBBLEARNPASSWD
    unset DBBBLEARNSTATSPASSWD
    unset DBBBLEARNREPORTPASSWD
    unset DBBBLEARNADMINPASSWD
    unset DBBBLEARNCMSPASSWD
    unset ADMINNAME
    unset ADMINEMAIL
    unset INSTNAME
    unset INSTCITY
    unset INSTSTATE
    unset INSTZIP
    unset INSTCOUNTRY
    unset INSTTYPE
    unset ADMINPASSWD
    unset ROOTADMINPASSWD
    unset INTGRPASSWD
    unset GUESTPASSWD
    unset JAVAKEYSTORE
    unset KEYSTOREFILE
    unset KEYSTOREPASSWD
    unset KEYSTORETYPE
    unset JVMSETTINGS
    unset MINHEAPSIZE
    unset MAXHEAPSIZE
    unset MAXSTACKSIZE
    unset JVMOPTIONS
    unset JVMGCOPTIONS
    
    # reset CONFIGPARAMETERS
    CONFIGPARAMETERS=()

    # check if blackboard learn is installed in default location
    getBBHome

    # add to CONFIGPARAMETERS ARRAY blackboard home, it should already be set at this point
    CONFIGPARAMETERS+=("bbconfig.basedir=${BBHOME}")

    # what type of configuration are we generating?
    while [[ "${INSTALLOPTION}" -lt 1 ]] || [[ "${INSTALLOPTION}" -gt 3 ]] && [[ -z "${INSTALLOPTION}" ]]; do
        # What type of install, Full or app only
        echo
        echo "[1] - Full Install"
        echo "[2] - App Only Install"
        echo "[3] - Full Upgrade"
        echo "[4] - App Only Upgrade"
        echo
        read -p "Please enter choice: " INSTALLOPTION
    done

    echo
    echo "Enter required Config parameter values."
    echo "Items that can be left blank with a default value are indicated by * - asterisk"
    echo

    # We should set SHARED_CONTENT location, otherwise default is [BLACKBOARD_HOME]/content
    if [[ "${INSTALLOPTION}" -eq 1 ]] || [[ "${INSTALLOPTION}" -eq 2 ]]; then

        read -p "Enter Shared Content Location [i.e. ${BBHOME}/content]*: " SHAREDCONTENTLOC

        # if left blank, we'll set it to the default
        if [ -z "${SHAREDCONTENTLOC}" ]; then
            SHAREDCONTENTLOC="${BBHOME}/content"
        fi

        # If this is an App Only Install and Shared Content Location is mounted, let's pull in configuration values
        # from bb-config.properties.original within the shared content to pre-populate parameters
        if [ "${INSTALLOPTION}" -eq 2 ]; then

            # Verify if bb-config.properties.original can be found in shared content
            if [ -f "${SHAREDCONTENTLOC}/loadbalancing/bb-config.properties.original" ]; then
                echo "bb-config.properties.original found within SHARED_CONTENT!"
                BBCONFIG="${SHAREDCONTENTLOC}/loadbalancing/bb-config.properties.original"
                echo "BBCONFIG now set to ${BBCONFIG}"
            else
                echo "SHARED_CONTENT Location not found or not mounted!"
                echo "Please Mount Shared Content before proceeding"
                echo "Now exiting..."
                exit 1
            fi
        fi

        # add to CONFIGPARAMETERS ARRAY
        if [ "${INSTALLOPTION}" -ne 3 ]; then
            CONFIGPARAMETERS+=("bbconfig.base.shared.dir=${SHAREDCONTENTLOC}")
        fi
    fi

    # License File Location, this is required for all scenarios
    while [[ -z "${LICENSEFILE}" ]] || [[ ! -f "${LICENSEFILE}" ]]; do

        # Provide a hint if upgrading
        if [ "${INSTALLOPTION}" -eq 3 ] || [ "${INSTALLOPTION}" -eq 4 ]; then
            echo "Please make sure LICENSE File is located outside of ${BBHOME}"
        fi

        read -p "Enter License File Location [i.e. /usr/local/license.xml] " LICENSEFILE

        # License File not found
        if [ ! -f "${LICENSEFILE}" ]; then
            echo "License File not found!, enter valid location!"
        fi

        # check to ensure the license specified did not come from within BBHOME since there will be problems using a license there
        if [ "$(echo ${LICENSEFILE} | grep -ic '^${BBHOME}')" -eq 1 ] && [ -f "${LICENSEFILE}" ]; then

            echo "License File cannot be located within BLACKBOARD_HOME"

            # do you want to copy it locally?
            while [[ -z "${COPYLICENSE}" ]] || [[ "$(echo ${COPYLICENSE} | grep -ic 'y\|n')" -eq 0 ]]; do
                read -p "Do you want to copy it locally here? [y/N]: " COPYLICENSE

                if [ "$(echo ${COPYLICENSE}) | grep -ic 'y'" -eq 1 ]; then
                    echo "Copying License locally!"
                    cp ${LICENSEFILE} .
                    # Set new LICENSEFILE location
                    LICENSEFILE=$(pwd)/$(echo "${LICENSEFILE}" | xargs -n 1 basename)
                fi
            done
        fi
    done

    # add to CONFIGPARAMETERS ARRAY
    CONFIGPARAMETERS+=("bbconfig.file.license=${LICENSEFILE}")

    # Ensure that we change the bbconfig.java.home if we are upgrade to ensure that JDK8 is used.
    if [[ "${INSTALLOPTION}" -eq 3 ]] || [[ "${INSTALLOPTION}" -eq 4 ]]; then

        # Set JDK Path from BBCONFIG
        JDKPATH=$(grep 'bbconfig.java.home=' ${BBCONFIG} | sed 's/bbconfig.java.home=//')

        # check what version of JDK is being used for bbconfig.java.home
        while [ "$(${JDKPATH}/bin/java -version 2>&1 | awk '/version/{print $NF}' | grep -c 1.8)" -eq 0 ]; do
            echo "bbconfig.java.home is not set to JDK8"
            echo "Please specify an override value to JDK8 location"
            read -p "Enter JDK8 Location [i.e. /usr/local/jdk1.8.0_90]: " JDKPATH
        done

        # Setting the override
        if [[ "$(${JDKPATH}/bin/java -version 2>&1 | awk '/version/{print $NF}' | grep -c 1.8)" -eq 1 ]]; then
            CONFIGPARAMETERS+=("bbconfig.java.home=${JDKPATH}")
        fi
        
    fi

    # App Server and Machine Name, required for all Installs, not for upgrades
    if [[ "${INSTALLOPTION}" -eq 1 ]] || [[ "${INSTALLOPTION}" -eq 2 ]]; then
        # App Server Full Hostname
        while [[ -z "${APPSERVERFULLHOSTNAME}" ]]; do
            read -p "Enter App Server Full hostname [i.e. app01.local]: " APPSERVERFULLHOSTNAME
        done

        # Machine Name
        while [[ -z "${APPSERVERMACHINENAME}" ]]; do
            read -p "Enter App Server Machine name [i.e. ${APPSERVERFULLHOSTNAME}]*: " APPSERVERMACHINENAME
            # if empty, set to APPSERVERFULLHOSTNAME
            if [[ -z "${APPSERVERMACHINENAME}" ]]; then
                APPSERVERMACHINENAME=${APPSERVERFULLHOSTNAME}
            fi
        done

        # add to CONFIGPARAMETERS ARRAY
        CONFIGPARAMETERS+=("bbconfig.appserver.fullhostname=${APPSERVERFULLHOSTNAME}")
        CONFIGPARAMETERS+=("bbconfig.appserver.machinename=${APPSERVERMACHINENAME}")
    fi

    # prefill for App Server only Installs, we are already assuming that we have a connection to the shared content to pull bbconfig data
    if [ "${INSTALLOPTION}" -eq 2 ] && [[ -f "${BBCONFIG}" ]]; then
        # set value based on bb-config.properties.original
        DBHOSTNAME=$(grep 'bbconfig.database.server.fullhostname=' ${BBCONFIG} | sed 's/bbconfig.database.server.fullhostname=//')
        DBPORT=$(grep 'bbconfig.database.server.portnumber=' ${BBCONFIG} | sed 's/bbconfig.database.server.portnumber=//')
        DBINSTNAME=$(grep 'bbconfig.database.server.instancename=' ${BBCONFIG} | sed 's/bbconfig.database.server.instancename=//')
        DBDATADIR=$(grep 'bbconfig.database.datadir=' ${BBCONFIG} | sed 's/bbconfig.database.datadir=//')    
    fi

    # If performing App only Install or Upgrade, let's copy the DBSYSPASSWD
    if [ "${INSTALLOPTION}" -eq 2 ] || [ "${INSTALLOPTION}" -eq 4 ] && [[ -f "${BBCONFIG}" ]]; then
    	DBSYSPASSWD=$(grep 'bbconfig.database.server.systemuserpassword=' ${BBCONFIG} | sed 's/bbconfig.database.server.systemuserpassword=//')
    	DBBBLEARNPASSWD=$(grep 'antargs.default.vi.db.password=' ${BBCONFIG} | sed 's/antargs.default.vi.db.password=//')
    	DBBBLEARNSTATSPASSWD=$(grep 'antargs.default.vi.stats.db.password=' ${BBCONFIG} | sed 's/antargs.default.vi.stats.db.password=//')
		DBBBLEARNREPORTPASSWD=$(grep 'antargs.default.vi.report.user.password=' ${BBCONFIG} | sed 's/antargs.default.vi.report.user.password=//')
		DBBBLEARNADMINPASSWD=$(grep 'bbconfig.database.admin.password=' ${BBCONFIG} | sed 's/bbconfig.database.admin.password=//')
		DBBBLEARNCMSPASSWD=$(grep 'bbconfig.cs.db.cms-user.pass=' ${BBCONFIG} | sed 's/bbconfig.cs.db.cms-user.pass=//')
    fi

    # Required for a Full Install
    if [[ "${INSTALLOPTION}" -eq 1 ]]; then

        # Enter SMTP Server Full Hostname
        while [[ -z "${SMTPHOSTNAME}" ]]; do
            read -p "Enter SMTP Server [i.e. smtp.blackboard.local]: " SMTPHOSTNAME
        done

        # add to CONFIGPARAMETERS ARRAY
        CONFIGPARAMETERS+=("bbconfig.smtpserver.hostname=${SMTPHOSTNAME}")

        # Enter Frontend Full Hostname
        while [[ -z "${FRONTENDHOSTNAME}" ]]; do
            read -p "Enter Frontend Hostname [i.e. blackboard.local]: " FRONTENDHOSTNAME
        done

        # add to CONFIGPARAMETERS ARRAY
        CONFIGPARAMETERS+=("bbconfig.frontend.fullhostname=${FRONTENDHOSTNAME}")
        # Frontend Protocol should always be https
        CONFIGPARAMETERS+=("bbconfig.frontend.protocol=${FRONTENDPROTOCOL}")
        # Frontend Port should always be 443
        CONFIGPARAMETERS+=("bbconfig.frontend.portnumber=${FRONTENDPORT}")

    fi 

    # Database configuration details for Full Install
    if [[ "${INSTALLOPTION}" -eq 1 ]]; then

        # Specify Database Parameters
        while [[ -z "${DBHOSTNAME}" ]]; do
            read -p "Enter Database Full Hostname [db.blackboard.local]: " DBHOSTNAME
        done

        # Specify Database Type
        # Script is not yet setup for Windows options
        # please DO NOT uncomment the sqlserver specific lines
        while [[ -z "${DBTYPE}" ]]; do

            echo "[0] - oracle"
            #echo "[1] - mssql"

            read -p "Enter Database Type: " DBTYPECHOICE

            # depending on choice set the DBTYPE, this parameter is not really that important to be set but let's set it anyways
            case "${DBTYPECHOICE}" in
                0)
                    echo "DBTYPE set to oracle"
                    DBTYPE="oracle"
                    ;;
                #1)
                #   echo "DBTYPE set to mssql"
                #   DBTYPE="mssql"
                #   ;;
                *)
                    echo "Choice was Invalid"
                    ;;
            esac

        done

        # Specify Database Port Number
        while [[ -z "${DBPORT}" ]]; do
            read -p "Enter Database Port [i.e. ${DBDEFAULTPORT}]*: " DBPORT

            # if blank default to DBDEFAULTPORT
            if [[ -z "${DBPORT}" ]]; then
                DBPORT=${DBDEFAULTPORT}
            fi
        done

        # Specify Database Instance Name (i.e. SID)
        while [[ -z "${DBINSTNAME}" ]] && [[ "${DBTYPE}" == "oracle" ]]; do
            read -p "Enter Database Instance Name [i.e. ENG12R1]: " DBINSTNAME
        done

        # Specify Database SYSTEM User Password
        while [[ -z "${DBSYSPASSWD}" ]]; do
            read -p "Enter Databse System User Password [i.e. PASSWORD]: " DBSYSPASSWD
        done

        # Specify Database Files
        while [[ -z "${DBDATADIR}" ]]; do
            read -p "Enter Database files directory [i.e. /usr/local/bb_data]: " DBDATADIR
        done
    fi
    
    # add to CONFIGPARAMETERS ARRAY
    if [[ "${INSTALLOPTION}" -eq 1 ]] || [[ "${INSTALLOPTION}" -eq 2 ]]; then
        # add to CONFIGPARAMETERS ARRAY
        CONFIGPARAMETERS+=("bbconfig.database.type=${DBTYPE}")
        # Start Oracle Specific
        CONFIGPARAMETERS+=("bbconfig.database.server.instancenametype.oracle=${DBINSTNAMETYPE}")
        CONFIGPARAMETERS+=("bbconfig.oracle.client.drivertype=${DBDRIVETYPE}")
        # End Oracle Specific
        CONFIGPARAMETERS+=("bbconfig.database.server.portnumber=${DBPORT}")
        CONFIGPARAMETERS+=("bbconfig.database.datadir=${DBDATADIR}")
        CONFIGPARAMETERS+=("bbconfig.database.server.fullhostname=${DBHOSTNAME}")
        CONFIGPARAMETERS+=("bbconfig.database.server.instancename=${DBINSTNAME}")
        CONFIGPARAMETERS+=("bbconfig.database.server.systemuserpassword=${DBSYSPASSWD}")
    fi

    # BBLEARN database password for Installs
    while [[ -z "${DBBBLEARNPASSWD}" ]]; do
        read -p "Enter BBLEARN database password: " DBBBLEARNPASSWD
    done

    # add to CONFIGPARAMETERS ARRAY, this is required for both Full and App only install
    CONFIGPARAMETERS+=("antargs.default.vi.db.password=${DBBBLEARNPASSWD}")

    # Database parameters for Full Install
    if [[ "${INSTALLOPTION}" -eq 1 ]] || [[ "${INSTALLOPTION}" -eq 2 ]]; then
        # BBLEARN_STATS database password
        while [[ -z "${DBBBLEARNSTATSPASSWD}" ]]; do
            read -p "Enter BBLEARN_STATS database password [i.e. ${DBBBLEARNPASSWD}]*: " DBBBLEARNSTATSPASSWD
            if [ -z "${DBBBLEARNSTATSPASSWD}" ]; then
                DBBBLEARNSTATSPASSWD=${DBBBLEARNPASSWD}
            fi
        done

        # BBLEARN_REPORT database password
        while [[ -z "${DBBBLEARNREPORTPASSWD}" ]]; do
            read -p "Enter BBLEARN_REPORT database password [i.e. ${DBBBLEARNPASSWD}]*: " DBBBLEARNREPORTPASSWD
            if [ -z "${DBBBLEARNREPORTPASSWD}" ]; then
                DBBBLEARNREPORTPASSWD=${DBBBLEARNPASSWD}
            fi
        done

        # BBLEARN_ADMIN database password
        while [[ -z "${DBBBLEARNADMINPASSWD}" ]]; do
            read -p "Enter BBLEARN_ADMIN database password [i.e. ${DBBBLEARNPASSWD}]*: " DBBBLEARNADMINPASSWD
            if [ -z "${DBBBLEARNADMINPASSWD}" ]; then
                DBBBLEARNADMINPASSWD=${DBBBLEARNPASSWD}
            fi
        done

        # BBLEARN_CMS and BBLEARN_CMS_DOC database password
        while [[ -z "${DBBBLEARNCMSPASSWD}" ]]; do
            read -p "Enter BBLEARN_CMS database password [i.e. ${DBBBLEARNPASSWD}]*: " DBBBLEARNCMSPASSWD
            if [ -z "${DBBBLEARNCMSPASSWD}" ]; then
                DBBBLEARNCMSPASSWD=${DBBBLEARNPASSWD}
            fi
        done

        CONFIGPARAMETERS+=("antargs.default.vi.stats.db.password=${DBBBLEARNSTATSPASSWD}")
        CONFIGPARAMETERS+=("antargs.default.vi.report.user.password=${DBBBLEARNREPORTPASSWD}")
        CONFIGPARAMETERS+=("bbconfig.database.admin.password=${DBBBLEARNADMINPASSWD}")
        CONFIGPARAMETERS+=("bbconfig.cs.db.cms-user.pass=${DBBBLEARNCMSPASSWD}")
    fi
    
    # Ask for the following if fresh install
    if [ "${INSTALLOPTION}" -eq 1 ]; then
        # Institution Information
        # Admin Name
        read -p "Enter Admin Name [i.e. Blackboard Administrator]*: " ADMINNAME
        if [ -z "${ADMINNAME}" ]; then
            ADMINNAME="Blackboard Administrator"
        fi

        # Admin Email
        while [[ -z "${ADMINEMAIL}" ]]; do
            read -p "Enter Admin Email [i.e. admin@blackboard.local]: " ADMINEMAIL
        done

        # Institution Name
        while [[ -z "${INSTNAME}" ]]; do
            read -p "Enter Institution Name [i.e. Bb University]: " INSTNAME
        done

        # Institution City
        while [[ -z "${INSTCITY}" ]]; do
            read -p "Enter Institution City/Province [i.e. Arlington]: " INSTCITY
        done

        # Institution State
        while [[ -z "${INSTSTATE}" ]]; do
            read -p "Enter Institution State [i.e. VA]: " INSTSTATE
        done

        # Institution Zip Code
        while [[ -z "${INSTZIP}" ]]; do
            read -p "Enter Institution Zip/Postal Code [i.e. 22206]: " INSTZIP
        done

        # Institution Country
        while [[ -z "${INSTCOUNTRY}" ]]; do
            read -p "Enter Institution Country [i.e. USA]: " INSTCOUNTRY
        done

        # Institution Type
        while [[ -z "${INSTTYPE}" ]]; do
            read -p "Enter Institution Type [i.e. NAHE]: " INSTTYPE
        done


        # add to CONFIGPARAMETERS ARRAY
        CONFIGPARAMETERS+=("bbconfig.admin.name=${ADMINNAME}")
        CONFIGPARAMETERS+=("bbconfig.admin.email=${ADMINEMAIL}")
        CONFIGPARAMETERS+=("bbconfig.inst.name=${INSTNAME}")
        CONFIGPARAMETERS+=("bbconfig.inst.city=${INSTCITY}")
        CONFIGPARAMETERS+=("bbconfig.inst.state=${INSTSTATE}")
        CONFIGPARAMETERS+=("bbconfig.inst.country=${INSTCOUNTRY}")
        CONFIGPARAMETERS+=("bbconfig.inst.zip=${INSTZIP}")
        CONFIGPARAMETERS+=("bbconfig.inst.type=${INSTTYPE}")
    fi

    # One Time Passwords, these are not needed for Upgrades, so let's provide nulls
    if [[ "${INSTALLOPTION}" -eq 3 ]] || [[ "${INSTALLOPTION}" -eq 4 ]]; then
        ADMINPASSWD="######"
        ROOTADMINPASSWD="######"
        INTGRPASSWD="######"
        GUESTPASSWD="######"
    fi

    # Administrator Password
    while [[ -z "${ADMINPASSWD}" ]]; do
        read -p "Enter Administrator Password [i.e. ${DBBBLEARNPASSWD}]*: " ADMINPASSWD
        if [ -z "${ADMINPASSWD}" ]; then
            ADMINPASSWD=${DBBBLEARNPASSWD}
        fi
    done

    # Root Admin User Password
    while [[ -z "${ROOTADMINPASSWD}" ]]; do
        read -p "Enter Root Admin Password [i.e. ${ADMINPASSWD}]*: " ROOTADMINPASSWD
        if [ -z "${ROOTADMINPASSWD}" ]; then
            ROOTADMINPASSWD=${ADMINPASSWD}
        fi
    done

    # Integration User Password
    while [[ -z "${INTGRPASSWD}" ]]; do
        read -p "Enter Integration Password [i.e. ${ADMINPASSWD}]*: " INTGRPASSWD
        if [ -z "${INTGRPASSWD}" ]; then
            INTGRPASSWD=${ADMINPASSWD}
        fi
    done

    # Guest User Password
    while [[ -z "${GUESTPASSWD}" ]]; do
        read -p "Enter Guest Password [i.e. ${ADMINPASSWD}]*: " GUESTPASSWD
        if [ -z "${GUESTPASSWD}" ]; then
            GUESTPASSWD=${ADMINPASSWD}
        fi
    done

    CONFIGPARAMETERS+=("antargs.default.users.administrator.password=${ADMINPASSWD}")
    CONFIGPARAMETERS+=("antargs.default.users.rootadmin.password=${ROOTADMINPASSWD}")
    CONFIGPARAMETERS+=("antargs.default.users.integration.password=${INTGRPASSWD}")
    CONFIGPARAMETERS+=("antargs.default.users.guest.password=${GUESTPASSWD}")


    # Configure Java Keystore or override existing one?
    while [[ -z "${JAVAKEYSTORE}" ]] || [[ "$(echo ${JAVAKEYSTORE} | grep -ic 'y\|n')" -eq 0 ]] ; do
        read -p "Do you want to specify Java Keystore Certificate Information [y/N]: " JAVAKEYSTORE
    done

    # Manually set keystore information for a Learn Full/App Only install
    if [[ "$(echo ${JAVAKEYSTORE} | grep -ic 'y')" -eq 1 ]]; then

        # Enter Keystore File
        while [[ -z "${KEYSTOREFILE}" ]] && [[ ! -f "${KEYSTOREFILE}" ]]; do
            read -p "Enter Keystore File [i.e /usr/local/certs/cert.pfx]: " KEYSTOREFILE
        done

        # Enter Keystore Password
        while [[ -z "${KEYSTOREPASSWD}" ]]; do
            read -p "Enter Keystore File Passsword [i.e. password]: " KEYSTOREPASSWD
        done

        # Enter Keystore Type
        while [[ -z "${KEYSTORETYPE}" ]]; do
            read -p "Enter Keystore Type [i.e. PKCS12]: " KEYSTORETYPE
        done

        # add to CONFIGPARAMETERS ARRAY
        CONFIGPARAMETERS+=("bbconfig.appserver.keystore.filename=${KEYSTOREFILE}")
        CONFIGPARAMETERS+=("bbconfig.appserver.keystore.password=${KEYSTOREPASSWD}")
        CONFIGPARAMETERS+=("bbconfig.appserver.keystore.type=${KEYSTORETYPE}")
    fi
    

    # Configure JVM settings?
    if [[ "${INSTALLOPTION}" -ne 3 ]] && [[ "${INSTALLOPTION}" -ne 4 ]]; then
        while [[ -z "${JVMSETTINGS}" ]] || [[ "$(echo ${JVMSETTINGS} | grep -ic 'y\|n')" -eq 0 ]]; do
            read -p "Configure JVM Parameters [y/N]: " JVMSETTINGS
        done

        if [[ "$(echo ${JVMSETTINGS} | grep -ic 'y')" -eq 1 ]]; then
            # Min Heap Size
            while [[ -z "${MINHEAPSIZE}" ]]; do
                read -p "Enter bbconfig.min.heapsize.tomcat [i.e. 2048m]: " MINHEAPSIZE
            done
            # Max Heap Size
            while [[ -z "${MAXHEAPSIZE}" ]]; do
                read -p "Enter bbconfig.max.heapsize.tomcat [i.e. 2048m]: " MAXHEAPSIZE
            done
            # Max Stack Size
            while [[ -z "${MINHEAPSIZE}" ]]; do
                read -p "Enter bbconfig.max.stacksize.tomcat [i.e. 1M]: " MAXSTACKSIZE
            done
            # JVM Options
            while [[ -z "${JVMOPTIONS}" ]]; do
                read -p "Enter JVM Options (Separated by space): " JVMOPTIONS
            done
            # JVM GC Options
            while [[ -z "${JVMGCOPTIONS}" ]]; do
                read -p "Enter JVM GC Options (Separated by space): " JVMGCOPTIONS
            done

            # add to CONFIGPARAMETERS ARRAY
            CONFIGPARAMETERS+=("bbconfig.min.heapsize.tomcat=${MINHEAPSIZE}")
            CONFIGPARAMETERS+=("bbconfig.max.heapsize.tomcat=${MAXHEAPSIZE}")
            CONFIGPARAMETERS+=("bbconfig.max.stacksize.tomcat=${MAXSTACKSIZE}")
            CONFIGPARAMETERS+=("bbconfig.jvm.options.extra.tomcat=${JVMOPTIONS}")
            CONFIGPARAMETERS+=("bbconfig.jvm.options.gc=${JVMGCOPTIONS}")
        fi
    fi
    
}

# Write the installer.properties file
function writeToFile() {

    echo "${INSTALLERPROPFILENAME} file will be written to ${INSTALLERPROP}"

    while [[ -z "${FILELOCATIONCONFIRM}" ]] || [[ "$(echo ${FILELOCATIONCONFIRM} | grep -ic 'y\|n')" -eq 0 ]]; do
        read -p "Is this acceptable? [y/N]: " FILELOCATIONCONFIRM
    done

    if [ "$(echo ${FILELOCATIONCONFIRM} | grep -ic 'n')" -eq 1 ]; then
        while [ -z "${NEWFILELOCATION}" ]; do
            read -p "Enter full path for properties file [${INSTALLERPROP}]: " NEWFILELOCATION
        done

        # set path to new one
        INSTALLERPROP=${NEWFILELOCATION}
    fi

    echo "Writing to ${INSTALLERPROP}..."
    echo > ${INSTALLERPROP}

    # cycle through parameters to be written to file
    for i in "${CONFIGPARAMETERS[@]}"; do
        echo "$i" >> ${INSTALLERPROP} 
    done

    echo "${INSTALLERPROP} completed!"
}

# Main function to kick off the process
function start {

    # Run the property parameter configuration Process
    configureFreshInstall

    # verify with user if the configured parrameters are acceptable
    while [[ -z "${GOODTOGO}" ]] || [[ "$(echo ${GOODTOGO} | grep -ic 'y')" -eq 0 ]]; do

        echo
        for i in "${CONFIGPARAMETERS[@]}"; do
            echo "$i"
        done
        echo

        read -p "Are configuration values acceptable? [y/N]: " GOODTOGO

        # if no, let's run configureFreshInstall again
        if [[ "$(echo ${GOODTOGO} | grep -ic 'n')" -eq 1 ]]; then
            configureFreshInstall
        elif [[ "$(echo ${GOODTOGO} | grep -ic 'y')" -ne 1 ]]; then
            echo "Input was not recognized, please try a valid value"
        fi
    done
    
    # generate the installer.properties file
    writeToFile
}

start
