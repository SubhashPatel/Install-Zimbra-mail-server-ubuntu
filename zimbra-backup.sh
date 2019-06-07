#!/bin/bash

################################################
# Zimbra backup script for open source edition #
################################################

ZIMBRA_HOME=/opt/zimbra
ZIMBRA_BIN=$ZIMBRA_HOME/bin
ZIMBRA_BACKUP_DIR=$ZIMBRA_HOME/backup 

BACKUP_DATE=`date +%G-%m-%d_%H-%M` 

# set default option is 0 (unset)
VERBOSE=0 

log()
{
    # verbose option is turn on
    if [ $VERBOSE -eq 1 ]; then
        echo $1
    fi
}

usage() 
{

    cat << EOF
zmbackup: zmbackup [-o path] -a|-u mailbox
EOF

}

backup_mailbox()
{
    mbox=$1
    log "start backup mailbox $mbox"

    if [ ! -z $2 ]; then
        $ZIMBRA_BIN/zmmailbox -z -m $mbox getRestURL "//?fmt=tgz" > $ZIMBRA_BACKUP_DIR/$2/$mbox-$BACKUP_DATE.tgz
        log "backup mailbox $mbox successful"
        log "backup to $ZIMBRA_BACKUP_DIR/$2"

    else
        $ZIMBRA_BIN/zmmailbox -z -m $mbox getRestURL "//?fmt=tgz" > $ZIMBRA_BACKUP_DIR/$mbox-$BACKUP_DATE.tgz 
        log "backup mailbox $mbox successful"
        log "backup to $ZIMBRA_BACKUP_DIR"
    fi
} 

create_pack_backup()
{   
    log "search domain"
    domains=`$ZIMBRA_BIN/zmprov gad`

    for domain in $domains; do
        log "start backup domain $domain" 

        # get all accounts from domain
        mboxs=`$ZIMBRA_BIN/zmprov -l gaa $domain`

        # check directory if -o is set
        mkdir -p $ZIMBRA_BACKUP_DIR/$domain

        # fetch account in tgz format
        for mbox in $mboxs; do
#            $ZIMBRA_BIN/zmmailbox -z -m $mbox getRestURL "//?fmt=tgz" > $ZIMBRA_BACKUP_DIR/$domain/$mbox-$BACKUP_DATE.tgz
            backup_mailbox $mbox $domain
        done

        # pack mailbox in domain
        cd $ZIMBRA_BACKUP_DIR/$domain
        tar czf $domain-$BACKUP_DATE.tgz `ls`
        mv $domain-$BACKUP_DATE.tgz $ZIMBRA_BACKUP_DIR
        cd $ZIMBRA_BACKUP_DIR
        rm -rf $ZIMBRA_BACKUP_DIR/$domain
        
        log "backup domain $domain successful"

    done
}

# Option
# zmbackup [-ah] [-u mailbox] [-o path] 
while getopts :aho:u:v OPTION; do
    case $OPTION in
        a )
            AFLAG=1
            ;;
        h )
            usage
            ;;
        o )
            if [ -z $OPTARG ]; then
                echo "-o option must specific path"
                exit 1
            else
                ZIMBRA_BACKUP_DIR=${OPTARG:0:${#OPTARG}-1} # substring from 0 to strlen - 1
            fi
            ;;
        u ) 
            if [ -z $OPTARG ]; then
                echo "-u option must specific mailbox"
            else
                UFLAG=$OPTARG
            fi
            ;;
        v )
            VERBOSE=1
            ;;
        # other option doesn't match
        * )
            usage
            exit 1
            ;;
    esac
done

# if not specific -a or -u it error and exit the script
if [ -z $UFLAG ] && [[ $AFLAG -ne 1 ]]; then
    echo "you must specific -a or -u option"
    exit 1
fi

# if UFLAG has value but AFLAG is used
if [ ! -z $UFLAG ] && [[ $AFLAG -eq 1 ]]; then
    echo "use -a or -u"
    exit 1
# if declare UFLAG
elif [ ! -z $UFLAG ]; then
    backup_mailbox $UFLAG
fi

# if AFLAG on
if [[ $AFLAG -eq 1 ]]; then
    create_pack_backup
fi
