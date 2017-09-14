DESCRIPTION = "Creates tags files for all build packages"

CROSS_REFERENCE_TOOL ?= "ctags"


do_cross_reference[depends] = "${CROSS_REFERENCE_TOOL}-native:do_populate_sysroot"

CROSS_REFERENCE_CMD_ctags = "ctags -R"
CROSS_REFERENCE_CMD_cscope = "cscope -Rbw"

python do_cross_reference () {
    os.chdir(d.getVar('S',True))
    retvalue = os.system(d.getVar("CROSS_REFERENCE_CMD_" + d.getVar('CROSS_REFERENCE_TOOL', True), True))
    if retvalue != 0:
        bb.warn("Can't create tags file for package: " + d.getVar('PN', True))
    else:
        bb.note("Tag file was created. See directory: " + d.getVar('S',True) + " for details")
}

addtask cross_reference after do_patch before do_build
