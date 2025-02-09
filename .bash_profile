export FILE_CONFIG_PERSO='/c/Users/user/.custom_config_file'

function getparam()
{
	cat $FILE_CONFIG_PERSO | grep "$1" | cut -d':' -f2
}

function setparam()
{
	if test -f "$FILE_CONFIG_PERSO"; then
		sed -i "/$1/d" $FILE_CONFIG_PERSO
	fi
	echo "$1:$2" >> $FILE_CONFIG_PERSO
}

function chaine()
{
	setparam chaine $1
}

function devno()
{
	setparam devno $1
}

function newwb()
{
	cmpt=0
	newBranchName=$(date +%d_%m_%y)
	while git show-ref --quiet "refs/heads/$newBranchName"
	do
		cmpt+=1
		newBranchName="$(date +%d_%m_%y)_$cmpt"
		echo $newBranchName
	done
	# wt && git fetch origin tramaint && git checkout tramaint && git reset --hard origin/tramaint
	# pjt
	git branch $newBranchName && git checkout $newBranchName && setparam wb $newBranchName
}

function getdev()
{
	echo "$(getparam chaine)-$(getparam devno)"
}

function gcom()
{
	git commit -m "[$(getdev)] $1"
}

function gitcpa()
{
	version=$1
	targetBranch="$(getdev)"
	if [ -n "${version}" ]; then
		targetBranch+="-${version}"
	fi
	# wt && git fetch origin $targetBranch
	git checkout $targetBranch && git cherry-pick $(git rev-list --reverse --grep "^\[$(getdev)\]" $targetBranch..$(getparam wb))
	if [ $? -gt 0 ]; then
		gitcp_conflict	
	else
		gitcpa-c
	fi
}

function gitcp_conflict()
{
	gconflict
	continue=$?
	conflicts=1
	if [ $continue -eq 1 ]; then
		git cherry-pick --abort
	fi
	gitcp-continue
	if [ $? -eq 0 ]; then
		gitcpa-c
	fi
}

function gitcp-continue()
{
	continue=0
	while [ $continue -eq 0 ] && [ $conflicts -eq 1 ]; 
	do
		sleep 1
		echo "continue"
		git cherry-pick --continue
		conflicts=$?
		if [ $conflicts -ne 0 ]; then
			gconflict
			continue=$?
		fi
	done
	if [ $continue -eq 1 ]; then
		git cherry-pick --abort
	fi
	return $continue
}

function gitcpa-c()
{
	echo "Everything went well!"
	#git push && pjt
}

function gconflict()
{
	statusFiles=$(git status --porcelain=1)
	filesToModify=()
	while IFS= read -r line; do
		shortStatus=$(echo $line | cut -d' ' -f1)
		requireAddRemove=0
		curFile=$(echo $line | cut -d' ' -f2)
		if [ ${shortStatus} = "UU" ] || [ ${shortStatus} = "AA" ]; then
			filesToModify+=($curFile)
		elif [ ${shortStatus} = "DU" ]; then
			requireAddRemove=1
			echo "The file $curFile was deleted by us ($(git branch --show-current)) and updated by them (source branch)"	
		elif [ ${shortStatus} = "UD" ]; then
			requireAddRemove=1
			echo "The file $curFile was updated by us ($(git branch --show-current)) and deleted by them (source branch)"	
		elif [ ${shortStatus} = "??" ] || [ ${#shortStatus} -ne 2 ]; then
			continue
		else
			echo "The status $shortStatus is not taken in charge by this program. Please manually manage the files, then use gitcp-continue"
			git status
			return 2	
		fi

		if [ $requireAddRemove -eq 1 ]; then
			validResponse=0
			while [ $validResponse -eq 0 ];
			do
				read -p "What do you want to do with this file ? (add, rm, abort):" whatToDo < /dev/tty
				echo $whatToDo
				if [ -z "$whatToDo" ]; then
					echo "whatToDo is empty"
					sleep 1s
				elif [ "${whatToDo}" = "add" ]; then
					git add $curFile
					validResponse=1
				elif [ "${whatToDo}" = "rm" ]; then
					git rm $curFile
					validResponse=1
				elif [ "${whatToDo}" = "abort" ]; then
					echo "abort"
					return 1
				else
					echo "WhatToDo is bizarre"
					sleep 1s
				fi
			done
		fi
	done <<< "$statusFiles"
	mergeConflicts=1
	for fileToModify in ${filesToModify[@]};
	do
		code $fileToModify
	done

	while [ $mergeConflicts -eq 1 ];
	do
		read -p "Did you take care of all conflicts ? (y:continue, n: abort):" continueCherryPick
		if [ "$continueCherryPick" = "n" ]; then
			return 1
		elif [ "$continueCherryPick" = "y" ]; then
			if [ -z "$(git diff --check)" ]; then
				mergeConflicts=0
			else
				conflictFiles=$(git diff --check)
				echo "There still are conflicts in the files, please take care of it before continuing"

				while IFS= read -r line; do
					filename=$(echo $line | cut -d':' -f1)
					code $filename
				done <<< "$conflictFiles"
			fi
		fi
	done
	while IFS= read -r line; do
		shortStatus=$(echo $line | cut -d' ' -f1)
		if [ ${shortStatus} = "UU" ] || [ ${shortStatus} = "AA" ]; then
			git add $(echo $line | cut -d' ' -f2)	
		fi
	done <<< "$statusFiles"
	return 0;
}

alias gitbash_refresh=". /c/Users/user/.bash_profile"
alias pjt="cd ~/Documents/Grandir && git checkout $(getparam wb)"
alias gitcp="git cherry-pick"
alias gitc="git checkout"
# améliorations potentielles:
# - ne pas ouvrir l'editeur pour la gestion des messages liés à un problème de merge
# - ouvrir les fichiers en conflits un par un et attendre qu'il soit fermé
# - feature git add avec diff intégré