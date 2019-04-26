#!/bin/bash

####### convert number to english
digits=(
    "" one two three four five six seven eight nine
    ten eleven twelve thirteen fourteen fifteen sixteen seventeen eightteen nineteen
)
tens=("" "" twenty thirty forty fifty sixty seventy eighty ninety)
units=("" thousand million billion trillion)

function number2words() {
    local -i number=$((10#$1))
    local -i u=0
    local words=()
    local group

    while ((number > 0)); do
        group=$(hundreds2words $((number % 1000)) )
        [[ -n "$group" ]] && group="$group ${units[u]}"

        words=("$group" "${words[@]}")

        ((u++))
        ((number = number / 1000))
    done
    echo "${words[*]}"
}

function hundreds2words() {
    local -i num=$((10#$1))
    if ((num < 20)); then
        echo "${digits[num]}"
    elif ((num < 100)); then
        echo "${tens[num / 10]} ${digits[num % 10]}"
    else
        echo "${digits[num / 100]} hundred $("$FUNCNAME" $((num % 100)) )"
    fi
}
####### convert number to english

testnet_chain_id="Binance-Chain-Nile"
testnet_node="http://data-seed-pre-0-s3.binance.org:80"

mainnet_chain_id="Binance-Chain-Tigris"
mainnet_node="http://dataseed1.binance.org:80"

testnet_bnbcli="./tbnbcli"
mainnet_bnbcli="./bnbcli"

while true; do
    echo "Do you want to send transaction to testnet or mainnet?"
    echo "1 for testnet"
    echo "2 for mainnet"

    read env

    case ${env} in
        [1] )
            echo "Ok, you choose testnet"
            chain_id=${testnet_chain_id}
            node=${testnet_node}
            bnbcli=${testnet_bnbcli}
            break;;
        [2] )
            echo "Ok, you choose mainnet"
            chain_id=${mainnet_chain_id}
            node=${mainnet_node}
            bnbcli=${mainnet_bnbcli}
            break;;
        * ) echo 'Please input 1 or 2';;
    esac
done

if [[ ! -f "${bnbcli}" ]]; then
	echo "bnbcli does not exist!"
	exit 1
fi

# Get account type
while true; do
    echo "Will you use Ledger or local key store to sign the transactions?"
    echo "1 for legder"
    echo "2 for local key store"

    read account_type

    case ${account_type} in
        [1] )
            echo "Ok, you choose legder"
            break;;
        [2] )
            echo "Ok, you choose local key store"
            break;;
        * ) echo 'Please input 1 or 2';;
    esac
done

# Get accounts
while true; do
    echo "Where is your bnbcli home?(default is ~/.bnbcli, just press enter if you want to use default)"
    read bnbcli_home
    if [[ "${bnbcli_home}" == "" ]]
    then
        bnbcli_home="${HOME}/.bnbcli"
        echo "You choose default home!"
    fi

    if [[ ! -d "$bnbcli_home" ]]; then
	    echo "bnbcli home(${bnbcli_home}) does not exist!"
        continue
    fi

    if [[ ${account_type} == "1" ]]
    then
        accounts=$(echo "$(${bnbcli} keys list )" | grep ledger)
        if [[ "${accounts}" == "" ]]
        then
            echo "there is no account exist"
            continue
        fi
        echo "${accounts}"
    else
        accounts=$(echo "$(${bnbcli} keys list )" | grep local)
        if [[ "${accounts}" == "" ]]
        then
            echo "there is no account exist"
            continue
        fi
        echo "${accounts}"
    fi
    break
done

# Get account name
while true; do
    echo "Which account do you want to use?"
    read account_name
    if [[ "${account_name}" == "" ]]
    then
        echo "Please input account name"
        continue
    fi

    result=$(echo "${accounts}" | awk '{print $1}' | grep "^${account_name}$")
    if [[ "${result}" == "" ]]
    then
        echo "${account_name} does not exist"
        continue
    fi
    break
done

# Get deposit amount
while true; do
    echo "What is the deposit BNB amount for Listing(real number)?(you should deposit 1000BNB in mainnet and 2000BNB in testnet)"
    read deposit_amount

    result=$(echo ${deposit_amount} | grep "^[1-9][0-9]*$")
    if [[ "$result" == ""  ]]
    then
        echo "supply should only contains numeric characters"
        continue
    fi

    english_version=$(number2words ${deposit_amount})
    echo "deposit amount is ${english_version}(${deposit_amount})BNB, which will be showed as ${deposit_amount}00000000 in command, enter Y to continue, enter other key to input again"
    read retry
    case ${retry} in
        [Yy] )
            break;;
        * )
            continue;;
    esac
done

# Get base asset
while true; do
    echo "What is the base asset?"
    read base_asset

    result=$(echo ${base_asset} | grep "^[0-9|a-z|A-Z|\.|-]\{3,20\}$")
    if [[ "$result" == ""  ]]
    then
        echo "base asset should only contains 3~20 alphanumeric characters or '-', please try again"
        continue
    else
        base_asset=$(echo ${base_asset} | tr a-z A-Z)
        break
    fi
done

# Get quote asset
while true; do
    echo "What is the quote asset?"
    read quote_asset

    result=$(echo ${quote_asset} | grep "^[0-9|a-z|A-Z|\.|-]\{3,20\}$")
    if [[ "$result" == ""  ]]
    then
        echo "quote asset should only contains 3~20 alphanumeric characters or '-', please try again"
        continue
    else
        quote_asset=$(echo ${quote_asset} | tr a-z A-Z)
        break
    fi
done

# Get list price
while true; do
    echo "What is the list price against ${quote_asset}?"
    read real_list_price

    result=$(echo ${real_list_price} | grep "^[0-9|\.]*$")
    if [[ "$result" == ""  ]]
    then
        echo "list price should only contains numeric characters"
        continue
    fi
    list_price=$(echo $(echo "${real_list_price} * 100000000"|bc) | cut -d '.' -f1)
    echo "list price is ${real_list_price}${quote_asset}, which will be showed as ${list_price} in command, enter Y to continue and enter other key to input again"
    read retry
    case ${retry} in
        [Yy] )
            break;;
        * )
            continue;;
    esac
done

now_timestamp=$(date '+%s')

# Get voting period
while true; do
    echo "How long do you give Validators to vote (a decimal number in hours)?"
    read voting_period

    result=$(echo ${voting_period} | grep "^[1-9][0-9]*$")
    if [[ "$result" == ""  ]]
    then
        echo "voting period should only contains numeric characters"
        continue
    fi

    if [[ $((voting_period)) -gt 336 ]]
    then
        echo "voting period should less than 2 weeks"
    fi

    voting_period=$(($((voting_period))*3600))

    timestamp=$(($((now_timestamp))+$((voting_period))))
    uname="$(uname -s)"
    case "${uname}" in
        Linux*)
            expire_date=$(date -d @${timestamp} "+%Y-%m-%d %H:%M")
        ;;
        Darwin*)
            expire_date=$(date -r ${timestamp} "+%Y-%m-%d %H:%M")
        ;;
        *)
            expire_date=${timestamp}
        ;;
    esac

    echo "Validators have to vote for your proposal before ${expire_date}, enter Y to continue, enter other key to input again:"
    read retry
    case ${retry} in
        [Yy] )
            break;;
        * )
            continue;;
    esac
done


# Get expire time
while true; do
    echo "How long do you give yourself to run list command before expire (a decimal number in days)?"
    read expire_days

    result=$(echo ${expire_days} | grep "^[1-9][0-9]*$")
    if [[ "$result" == ""  ]]
    then
        echo "expire days should only contains numeric characters"
        continue
    fi

    if [[ $((expire_days)) -gt 30 ]]
    then
        echo "expire days should less than 30"
    fi

    expire_timestamp=$(($(date '+%s')+$((voting_period))+$((expire_days))*86400))

    uname="$(uname -s)"
    case "${uname}" in
        Linux*)
            expire_date=$(date -d @${expire_timestamp} "+%Y-%m-%d %H:%M")
        ;;
        Darwin*)
            expire_date=$(date -r ${expire_timestamp} "+%Y-%m-%d %H:%M")
        ;;
        *)
            expire_date=${expire_timestamp}
        ;;
    esac

    echo "You have to list your trading pair before ${expire_date}, enter Y to continue, enter other key to input again:"
    read retry
    case ${retry} in
        [Yy] )
            break;;
        * )
            continue;;
    esac
done

command="${bnbcli} gov submit-list-proposal --from ${account_name} --deposit ${deposit_amount}00000000:BNB --base-asset-symbol ${base_asset} --quote-asset-symbol ${quote_asset} --init-price ${list_price} --title \"list ${base_asset}/${quote_asset}\" --description \"list ${base_asset}/${quote_asset}\" --expire-time ${expire_timestamp} --voting-period ${voting_period} --chain-id=${chain_id} --trust-node --node ${node} --home ${bnbcli_home} --json "
list_command="${bnbcli} dex list --from {owner_account} --proposal-id {proposal_id} --node ${node} --chain-id ${chain_id} --init-price ${list_price} -s ${base_asset} --quote-asset-symbol ${quote_asset} --home ${bnbcli_home}"
echo "Below is the command to be executed"
echo "*****************************************************"
echo ${command}
echo "*****************************************************"
echo "And below is the list command, please replace owner account and proposal id if proposal passed. "
echo "*****************************************************"
echo ${list_command}
echo "*****************************************************"
echo "enter Y to execute and enter N to abort!"
while true; do
    read execute

    case ${execute} in
        [Yy] )
            ${bnbcli} gov submit-list-proposal --from ${account_name} --deposit ${deposit_amount}00000000:BNB --base-asset-symbol ${base_asset} --quote-asset-symbol ${quote_asset} --init-price ${list_price} --title "list ${base_asset}/${quote_asset}" --description "list ${base_asset}/${quote_asset}" --expire-time ${expire_timestamp} --chain-id=${chain_id} --voting-period ${voting_period} --trust-node --node ${node} --home ${bnbcli_home} --json
            break;;
        [Nn] )
            exit
            break;;
        * ) echo 'Please input Y or N';;
    esac
done

