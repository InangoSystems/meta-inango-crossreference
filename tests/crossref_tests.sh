#!/bin/bash
# Copyright (C) 2019 Inango Systems Ltd
# Released under the ******  license (see COPYING.INANGO for the terms)
#
# Run this script by full path from build directory after source Yocto environment
#
# This is temporary solution for tests

image_name=core-image-minimal
target_recipe=quilt
native_recipe=quilt-native

main()
{
    if [ "$1" = "-v" ]; then
        set -x
    fi

    utest TEST_no_recipes_parsing_errors

    utest TEST_cross_ref_meta_layer_used
    utest TEST_target_recipe_has_cross_reference_tasks
    utest TEST_native_recipe_has_cross_reference_tasks
    utest TEST_target_recipe_has_no_merge_all_cross_reference_task
    utest TEST_image_recipe_has_cross_reference_tasks
    utest TEST_image_has_merge_all_cross_reference_task
    utest TEST_crossref_vars_for_image
    utest TEST_crossref_vars_for_target_recipe
    utest TEST_crossref_vars_for_native_recipe
    utest TEST_no_include_crossref_vars_for_image
    utest TEST_no_include_crossref_vars_for_target_recipe
    utest TEST_no_include_crossref_vars_for_native_recipe

    utest TEST_do_cr_for_target_recipe
    utest TEST_do_cr_for_native_recipe
    utest TEST_do_cr_for_image

    utest TEST_do_merge_cr_for_image

    echo
    echo "==== SUCCESS ===="
}

################################################################################
TEST_no_recipes_parsing_errors()
{
    bitbake -p "$image_name"
}

################################################################################
TEST_cross_ref_meta_layer_used()
{
    # TODO: use variable with name of layer
    bitbake-layers show-layers | grep -P "meta-inango"
}

TEST_target_recipe_has_cross_reference_tasks()
{
    crossref_tasks_are_present "$target_recipe"
}

TEST_native_recipe_has_cross_reference_tasks()
{
    crossref_tasks_are_present "$native_recipe"
}

crossref_tasks_are_present()
{
    local recipe=$1
    task_is_present "$recipe" do_cross_reference
    task_is_present "$recipe" do_cross_reference_setscene
    task_is_present "$recipe" do_all_cross_reference
}

task_is_present()
{
    local recipe=$1
    local task=$2

    bitbake -clisttasks "$recipe" | grep --word-regexp "$task"
}

################################################################################
TEST_target_recipe_has_no_merge_all_cross_reference_task()
{
    task_is_absent "$target_recipe" do_merge_all_cross_reference
    task_is_absent "$target_recipe" do_merge_all_cross_reference_setscene
}

task_is_absent()
{
    local recipe=$1
    local task=$2

    bitbake -clisttasks "$recipe" | grep -v --word-regexp "$task"
}

################################################################################
TEST_image_recipe_has_cross_reference_tasks()
{
    crossref_tasks_are_present "$image_name"
}

################################################################################
TEST_image_has_merge_all_cross_reference_task()
{
    task_is_present "$image_name" do_merge_all_cross_reference
}

################################################################################
TEST_crossref_vars_for_image()
{
    local tf=$(mktemp)
    bitbake -e "$image_name" > "$tf"

    if ! grep -P '^CROSS_REFERENCE_TOOL="ctags"'            "$tf" || \
       ! grep -P '^CROSS_REFERENCE_TAG_NAME="tags"'         "$tf" || \
       ! grep -P '^CROSS_REFERENCE_ALLTAGS_FILENAME="tags"' "$tf";
    then
        ret=1;
    fi

    rm "$tf"
    return $ret
}

################################################################################
TEST_crossref_vars_for_target_recipe()
{
    local tf=$(mktemp)
    bitbake -e "$target_recipe" > "$tf"

    if ! grep -P '^CROSS_REFERENCE'            "$tf" || \
       ! grep -P '^CROSS_REFERENCE_TAG_NAME="tags"'         "$tf" || \
         grep -P '^CROSS_REFERENCE_ALLTAGS_FILENAME' "$tf" || \
         grep -P '^CROSS_REFERENCE_MERGE' "$tf";
    then
        ret=1;
    fi

    rm "$tf"
    return $ret
}

################################################################################
TEST_crossref_vars_for_native_recipe()
{
    local tf=$(mktemp)
    bitbake -e "$native_recipe" > "$tf"

    if ! grep -P '^CROSS_REFERENCE'            "$tf" || \
       ! grep -P '^CROSS_REFERENCE_TAG_NAME="tags"'         "$tf" || \
         grep -P '^CROSS_REFERENCE_ALLTAGS_FILENAME' "$tf" || \
         grep -P '^CROSS_REFERENCE_MERGE' "$tf";
    then
        ret=1;
    fi

    rm "$tf"
    return $ret
}


TEST_no_include_crossref_vars_for_image()
{
    env_vars_are_absent_for_recipe_by_regexp "$image_name" '(^INCLUDE_CROSS_REFERENCE.*|do_include_cross_reference)'
}

TEST_no_include_crossref_vars_for_target_recipe()
{
    env_vars_are_absent_for_recipe_by_regexp "$target_recipe" '(^INCLUDE_CROSS_REFERENCE.*|do_include_cross_reference)'
}

TEST_no_include_crossref_vars_for_native_recipe()
{
    env_vars_are_absent_for_recipe_by_regexp "$native_recipe" '(^INCLUDE_CROSS_REFERENCE.*|do_include_cross_reference)'
}

TEST_do_cr_for_target_recipe()
{
    bitbake -f -ccross_reference "$target_recipe"
}

TEST_do_cr_for_native_recipe()
{
    bitbake -f -ccross_reference "$native_recipe" | grep 'is ignored for cross-reference'
}

TEST_do_cr_for_image()
{
    bitbake -f -ccross_reference "$image_name"
}

TEST_do_merge_cr_for_image()
{
    bitbake -cmerge_all_cross_reference "$image_name"

    recipe_env_file="${image_name}.env"
    [ -f "${recipe_env_file}" ] || bitbake -e "$image_name" > "${recipe_env_file}"

    d=$(grep -o -P '^CROSS_REFERENCE_ALLTAGS_DIR=.*$' "${recipe_env_file}" | cut -d= -f 2 | sed 's/"//g')
    f=$(grep -o -P '^CROSS_REFERENCE_ALLTAGS_FILENAME=.*$' "${recipe_env_file}" | cut -d= -f 2 | sed 's/"//g')

    echo "$d/$f"
    test -f "$d/$f"
}

env_vars_are_absent_for_recipe_by_regexp()
{
    local recipe=$1
    local regex=$2

    local tf=$(mktemp)
    bitbake -e "$recipe" > "$tf"
    grep -P "$regex" "$tf"
    local ret=$?
    rm "$tf"

    [ "$ret" = "0" ] && return 1
    return 0
}


################################################################################
utest()
{
    echo
    echo "==== RUN TEST \"$1\" ===="
    if ! $1; then
        echo "[FAILED] $1"
        exit 1
    else
        echo "[OK] $1"
    fi
    echo "==== END TEST \"$1\" ===="
}

main "$@"
