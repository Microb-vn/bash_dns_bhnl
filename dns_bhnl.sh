#!/bin/bash
#
# acme DNS API script for dutch provider bhosted.nl
#
# bhosted has a very simple web API, with only a few commands
# The exact syntax of these commands is only published to members of bhosted.nl
#
# Domain names registered via bhosted are always in format
# - tld - top level domain (com, nl, org, etc..)
# - sld - sub level domain (whatever, mydomain, etc..)
# Login is done using used ID and (hashed) password
# bhosted requires IP address where the calls are made from
# are registered in their web control panel

BHNL_Api=https://webservices.bhosted.nl

##########################TEMPORARY FUNCTIONS, REMOVE DURING FINAL TESTING - BEGIN
##########################
###################
#######
. exports.sh # Contains "secrets", file is not published to GH:
# export BHNL_Account=aaaa
# export BHNL_Password=ppppppppp
# export BHNL_sld=sssssss
# export BHNL_tld=tt

_saveaccountconf_mutable(){
    _debug "saveaccountconf_mutable - saved - $1 $2"
}

_get(){
    _url=$1

    curl $_url
}

_debug(){
    _txt=$@
    echo "DEBUG:$_txt"
}
_info(){
    _txt=$@
    echo "INFO:$_txt"
}
_err(){
    _txt=$@
    echo "ERROR:$_txt"
}
######
####################
##########################
# THERE IS MORE TEST CODE AT THE BOTTOM!!!!!!
##########################TEMPORARY FUNCTIONS, REMOVE DURING FINAL TESTING - END

######## Public Functions ###############################

# Usage: dns_bhnl_add _acme-challenge.domain.com "oiusefhjkdsfiupwqi123kjlsaiduaasd"
dns_bhnl_add() {
    fulldomain=$1
    txtvalue=$2

    _info "Start add DNS TXT record for $fulldomain with TXT value '$txtvalue'"
    BHNL_Account="${BHNL_Account:-(_readaccountconf_mutable BHNL_Account)}"
    BHNL_Password="${BHNL_Password:-(_readaccountconf_mutable BHNL_Password)}"
    BHNL_sld="${BHNL_sld:-(_readaccountconf_mutable BHNL_sld)}"
    BHNL_tld="${BHNL_tld:-(_readaccountconf_mutable BHNL_tld)}"

    if  [[ -z "$BHNL_sld" ]] || [[ -z "$BHNL_tld" ]] ; then
        # domain info incomplete (no toplevel and/or subdomain)
        BHNL_sld=""
        BHNL_tld=""
        _err "Incomplete domain info."
        return 1
    fi
    if  [[ -z "$BHNL_Account" ]] || [[ -z "$BHNL_Password" ]] ; then
        # domain info incomplete (no or invalid login data)
        BHNL_Account=""
        BHNL_Password=""
        _err "Incomplete domain login info."
        return 1
    fi

    # Save the info (which is possibly refreshed somehow...)
    _saveaccountconf_mutable BHNL_Account "$BHNL_Account"
    _saveaccountconf_mutable BHNL_Password "$BHNL_Password"
    _saveaccountconf_mutable BHNL_sld "$BHNL_sld"
    _saveaccountconf_mutable BHNL_tld "$BHNL_tld"

    _debug "Detect root zone/split subdomain"
    if ! _get_root "$fulldomain" ; then
        _err "invalid domain, or incorrect bhosted login info"
        return 1
    fi
    _debug _sub_domain "$_sub_domain"
    _debug _domain "$_domain"

    # We have the correct info, now add the TXT record
    _debug "Adding TXT record for $_sub_domain in $_domain with value '$txtvalue'"
    command="dns"
    subcommand="addrecord"
    type=TXT
    name="$_sub_domain"
    content="${txtvalue// /%20}" # (URLify the content in case it contains spaces)
    ttl=3600

    # The bhosted web api is a simple HTTP(S) request, no POST/GET/PUT. So a _get will work
    _get $BHNL_Api/$command/$subcommand?user=$BHNL_Account\&password=$BHNL_Password\&tld=$BHNL_tld\&sld=$BHNL_sld\&type=$type\&name=$name\&content=$content\&ttl=$ttl > tmp.xml

    # Find error node in returned XML, and check its value
    founderror=999
    foundid="notfound"
    while scan_xml; do
        if [ "$ENTITY" == "errors" ] ; then
            founderror="$CONTENT"
        fi
        if [ "$ENTITY" == "id" ] ; then
            foundid="$CONTENT"
        fi
        if [ "$founderror" != "999" ] &&  [ "$foundid" != "notfound" ] ; then
            break
        fi
    done < tmp.xml
    if [ "$founderror" != "0" ] || [ "$foundid" == "notfound" ] ; then
        _err "Add TXT record failed (see tmp.xml!)"
        return 1
    fi
    
    _info "TXT record succesfully added; recordid is $foundid"
}

# Usage: dns_bhnl_rm _acme-challenge.domain.com "oiusefhjkdsfiupwqi123kjlsaiduaasd"
dns_bhnl_rm() {
    fulldomain=$1
    txtvalue=$2

    _info "Start remove DNS TXT record for $fulldomain with value '$txtvalue'"
    BHNL_Account="${BHNL_Account:-(_readaccountconf_mutable BHNL_Account)}"
    BHNL_Password="${BHNL_Password:-(_readaccountconf_mutable BHNL_Password)}"
    BHNL_sld="${BHNL_sld:-(_readaccountconf_mutable BHNL_sld)}"
    BHNL_tld="${BHNL_tld:-(_readaccountconf_mutable BHNL_tld)}"

    if  [[ -z "$BHNL_sld" ]] || [[ -z "$BHNL_tld" ]] ; then
        # domain info incomplete (no toplevel and/or subdomain)
        BHNL_sld=""
        BHNL_tld=""
        _err "Incomplete domain info."
        return 1
    fi
    if  [[ -z "$BHNL_Account" ]] || [[ -z "$BHNL_Password" ]] ; then
        # domain info incomplete (no or invalid login data)
        BHNL_Account=""
        BHNL_Password=""
        _err "Incomplete domain login info."
        return 1
    fi

    _debug "Detect root zone/split subdomain"
    if ! _get_root "$fulldomain" ; then
        _err "invalid domain, or incorrect bhosted login info"
        return 1
    fi
    _debug _sub_domain "$_sub_domain"
    _debug _domain "$_domain"

    # We have the correct info, now try to find the TXT record to remove
    txtcontent="$txtvalue"
    _debug "Get TXT record ID for $_sub_domain in $_domain with value '$txtcontent'"
    command="dns"
    subcommand="getrecords"
    # wanted values!
    type=TXT
    name="$_sub_domain.$_domain"


    # The bhosted web api is a simple HTTP(S) request, no POST/GET/PUT. So a _get will work
    _get $BHNL_Api/$command/$subcommand?user=$BHNL_Account\&password=$BHNL_Password\&tld=$BHNL_tld\&sld=$BHNL_sld > tmp.xml

    # Find error node and record ID, and check error node value
    # This is an xml analyses, it is kind-of tricky in bash :-S
    founderror=999
    recordid=""
    areinrecord="no"
    while scan_xml; do
        if [ "$ENTITY" == "errors" ] ; then
            founderror="$CONTENT"
        elif [ "$ENTITY" == "record" ] ; then
            areinrecord="yes"
        elif [ "$ENTITY" == "/record" ] ; then
            areinrecord="no"
            # It happens here!
            if [ "$tmptype" == "TXT" ] && [ "$tmpname" == "$name" ] && [ "$tmpcontent" == "$txtcontent" ] ; then
                recordid="$tmpid"
                # We should continue to also find the errorcode; to speed things up we skip this
                # and assume we're ok when we have found a recordid
                break
            fi
            ## clear previous values (just to be sure)
            #tmptype=""
            #tmpname=""
            #tmpid=""
        elif [ "$ENTITY" == "id" ] && [ "$areinrecord" == "yes" ] ; then
            tmpid="$CONTENT"
        elif [ "$ENTITY" == "type" ] && [ "$areinrecord" == "yes" ] ; then
            tmptype="$CONTENT"
        elif [ "$ENTITY" == "name" ] && [ "$areinrecord" == "yes" ] ; then
            tmpname="$CONTENT"
        elif [ "$ENTITY" == "content" ] && [ "$areinrecord" == "yes" ] ; then
            tmpcontent=`sed -e 's/^"//' -e 's/"$//' <<< "$CONTENT"` # bhosted adds double quoutes around the content!
        fi
    done < tmp.xml
    # if [ "$founderror" != "0" ] ; then
    #     _err "Search for TXT record failed, an error was found (see tmp.xml!)"
    #     return 1
    # fi
    # do thorough validation before an actual delete of the record
    if [ -z "$recordid" ]  ; then
        _err "Search for TXT record failed, ID of TXT record could not be determined (see tmp.xml!)"
        return 1
    fi
    re='^[0-9]+$' # Regex for numeric (integer)
    if ! [[ $recordid =~ $re ]] ; then
        _err "Search for TXT record failed, ID of TXT record is not an integer (see tmp.xml!)"
        return 1
    fi
    
    # Display ID of found record
    _info "Found ID $recordid; will make attempt to remove"

    command="dns"
    subcommand="delrecord"
    # wanted values!
    # The bhosted web api is a simple HTTP(S) request, no POST/GET/PUT. So a _get will work
    _get $BHNL_Api/$command/$subcommand?user=$BHNL_Account\&password=$BHNL_Password\&tld=$BHNL_tld\&sld=$BHNL_sld\&id=$recordid > tmp.xml

    # Check if delete worked
    # Find error node and done node, and check their values
    founderror=999
    founddone="notfound"
    while scan_xml; do
        if [ "$ENTITY" == "errors" ] ; then
            founderror="$CONTENT"
            _debug "Found errorcode $CONTENT"
        fi
        if [ "$ENTITY" == "done" ] ; then
            founddone="$CONTENT"
            _debug "Found 'done' value $CONTENT"
        fi
        if [ "$founderror" != "999" ] && [ "$founddone" != "notfound" ] ; then
            break
        fi
    done < tmp.xml
    if [ "$founderror" != "0" ] || [ "$founddone" != "true" ]; then
        _err "Removal of TXT record failed (see tmp.xml!); PLEASE CHECK TXT RECORDS IN YOUR DNS CONSOLE!!!"
        return
    fi
    _info "Removal of TXT record (with id $recordid) executed with success!"

}

######## Private Functions ###############################
_get_root() {
    # bhosted domains are always $BHNL_sld.$BHNL_tld (e.g. mydomain.org)
    # With input _acme-challenge.www.domain.org
    # This function will return 
    # _sub_domain=_acme-challenge.www
    # _domain=domain.org
    #
    # This function is a bit overdone, it does not "determine" the root domain
    # because we already know what it is. Bhosted hosts simple domains.
    # The function uses the bhosted domain information function to see if all
    # parameters to access the API are correct and we have proper access, plus
    # it splits the domain in a domain and subdomain part
    domain=$1

    _domain="$BHNL_sld"."$BHNL_tld"

    command="domain"
    subcommand="info"
    url=$BHNL_Api/$command/$subcommand?user=$BHNL_Account\&password=$BHNL_Password\&tld=$BHNL_tld\&sld=$BHNL_sld

    _get "$url" > tmp.xml

    # Find error node, and check its value
    founderror=999
    while scan_xml; do
        if [ "$ENTITY" == "errors" ] ; then
            founderror="$CONTENT"
            break
        fi
    done < tmp.xml
    if [ "$founderror" != "0" ] ; then
        return 1
    fi

    _cutlength=$((${#domain} - ${#_domain} - 1))
    _sub_domain=$(printf "%s" "$domain" | cut -c "1-$_cutlength")

    return 0
    }

scan_xml() {
    # This function reads contents of an XML file and splits it into easy to understand
    # pieces. It needs to be used in a do loop. See this article:
    # https://readforlearn.com/how-to-parse-xml-in-bash/
    # Note that it is not a full blown XML parser, but it's good enough to process simple XML files
    local IFS=\>
    read -d \< ENTITY CONTENT
}

###### TEST CODE
#####
####
###
##
dns_bhnl_add "subd.rengunet.nl" "this is an acme test"
ret=$?
if [ "$ret" != "1" ] ; then
    dns_bhnl_rm "subd.rengunet.nl" "this is an acme test"
fi
return
