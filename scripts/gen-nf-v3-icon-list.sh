#!/bin/bash

# A script to generate the nf-v3-icon-list.lua file from nerd-fonts sources.
# Run this script from the icon-picker.nvim/scripts directory (where this file is).
# You must have a full clone of the nerd-fonts repo available locally.
# By default, this script looks for a repo directory called nerd-fonts in the 
# same parent directory as this repository (e.g. ~/src/nerd-fonts & ~/src/icon-picker.nvim).
# If your nerd-fonts repo is somewhere else, you may specify it as the one and only argument.

[[ -d "../../nerd-fonts/" ]] \
    && nf_repo_path="$(realpath ../../nerd-fonts)" \
    || nf_repo_path="$(realpath $1)"
icons_path="$nf_repo_path/bin/scripts/lib"
icon_sets=("cod" "dev" "fa" "fae" "iec" "logos" "md" "oct" "ple" "pom" "seti" "weather")
# Version tag of nerd-fonts to checkout.
nf_release_version="3.1.1"

# Add the nerd-fonts repo to the dir stack, checkout the desired branch, and return to initial dir.
pushd $nf_repo_path &> /dev/null
echo "Checking out version $nf_release_version"
git checkout "v$nf_release_version"
popd &> /dev/null

# Path of the icon table for the plugin.
nf_v3_icon_list_path=$(realpath ../lua/icon-picker/icons/nf-v3-icon-list.lua)
cat <<EOF > $nf_v3_icon_list_path
-- This file is generated by gen-nf-v3-icon-list.sh 
-- Do not edit this file manually, changes will be overwritten
-- Rerun the script to regenerate this file
-- Last ran against nerd-fonts v$nf_release_version

local icon_list = {
EOF

for set in "${icon_sets[@]}"; do
    # Read each line of the source file that does not start with #, test, or unset into an array.
    readarray -t icon_lines <<< $(grep -v '#\|test\|unset' "$icons_path/i_$set.sh")

    for line in "${icon_lines[@]}"; do
        # If the line start with i, it is a new icon.
        # Lines that contain additional names for an icon start with a space.
        if [[ $line =~ ^i ]]; then
            # Raw line: i='' i_fa_btc=$i
            #     Cut and keep everything between the equals signs.
            #     Remove the single quotes globally from the icon.
            #     Remove the leading i_ from the name.
            line=$( \
                cut -d= -f2 <<< $line |\
                sed "s/'//g" |\
                sed "s/i_//"
            )

            # After transform:  fa_btc
            icon_img="${line% *}"  # Take everything up to the first space. 
        else
            # Raw line: i_fa_bitcoin=$i_fa_btc
            #     Cut and keep everything before the equals sign.
            #     Remove the leading i_ from the name.
            line=$( \
                cut -d= -f1 <<< $line |\
                sed "s/i_//"
            )
        fi

        icon_name="${line##* }"  # Take everything after all leading spaces.
        
        echo "$icon_name $icon_img"
        echo "    [\"$icon_name\"] = \"$icon_img\"," >> $nf_v3_icon_list_path
    done
done

cat <<EOF >> $nf_v3_icon_list_path
}

return icon_list
EOF
