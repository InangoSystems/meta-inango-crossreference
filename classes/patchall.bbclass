# Copyright (C) 2018 Inango Systems Ltd
# Released under the ******  license (see COPYING.INANGO for the terms)

addtask patchall after do_patch
do_patchall[recrdeptask] = "do_patchall do_patch"
do_patchall[recideptask] = "do_${BB_DEFAULT_TASK}"
do_patchall() {
    :
}