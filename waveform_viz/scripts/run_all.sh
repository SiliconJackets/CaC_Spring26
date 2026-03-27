#!/bin/tcsh
#
# run_all.sh - Generate waveform GIFs for each module type
#
# Flow: VCS sim → FSDB → fsdb2vcd → VCD → Python GIF
#

# -- Paths -----------------------------------------------------------

set VIZ_DIR      = /nethome/ehuang303/SiliconJackets/Cac_Spring26/waveform_viz
set DESIGN_ROOT  = /nethome/ehuang303/SiliconJackets/Cac_Spring26/design_root
set SRC_PARTS    = ${DESIGN_ROOT}/src/verilog/parts
set SIM_DIR      = ${DESIGN_ROOT}/sim/behav
set TB_DIR       = ${VIZ_DIR}/testbenches
set INC_DIR      = ${VIZ_DIR}/include
set FSDB_DIR     = ${VIZ_DIR}/fsdb
set VCD_DIR      = ${VIZ_DIR}/vcd
set GIF_DIR      = ${VIZ_DIR}/gifs

# -- Setup VCS / Verdi environment -----------------------------------

setenv TERM xterm
setenv VCS_HOME /tools/software/synopsys/vcs/latest
if ( -f $VCS_HOME/bin/environ.csh ) then
    source $VCS_HOME/bin/environ.csh
endif

set FSDB2VCD = /tools/software/synopsys/verdi/latest/bin/fsdb2vcd

# -- Create output directories --------------------------------------

mkdir -p $FSDB_DIR $VCD_DIR $GIF_DIR

# -- Symlink source files --------------------------------------------

echo "=== Symlinking source files ==="
foreach svfile ( `find ${SRC_PARTS} -name '*.sv'` )
    ln -sf $svfile ${SIM_DIR}/`basename $svfile`
end
foreach sv ( ${TB_DIR}/*.sv )
    ln -sf $sv ${SIM_DIR}/`basename $sv`
end
foreach inc ( ${INC_DIR}/*.include )
    ln -sf $inc ${SIM_DIR}/`basename $inc`
end

# -- Helper to run one simulation ------------------------------------

# run_one <include_name> <output_name>
# Compiles with VCS, runs, produces FSDB

# -- SIMULATIONS (one per module type) -------------------------------

echo ""
echo "========================================"
echo " RUNNING SIMULATIONS"
echo "========================================"

# One representative controller (saturate — simplest, shows core behavior)
set inc_name = controller_saturate_viz
set out_name = controller
echo "--- ${out_name} ---"
cd $SIM_DIR && rm -rf simv simv.daidir csrc >& /dev/null
vcs -f ${inc_name}.include +v2k -R +lint=all -sverilog -full64 \
    -timescale=1ps/1ps -debug_access+all \
    -l ${FSDB_DIR}/${out_name}.log +define+SIM=1 \
    +fsdbpath=${FSDB_DIR}/${out_name}.fsdb -lca -kdb

# One representative phase detector (PFD — most common/standard)
set inc_name = pd_pfd_viz
set out_name = phase_detector
echo "--- ${out_name} ---"
cd $SIM_DIR && rm -rf simv simv.daidir csrc >& /dev/null
vcs -f ${inc_name}.include +v2k -R +lint=all -sverilog -full64 \
    -timescale=1ps/1ps -debug_access+all \
    -l ${FSDB_DIR}/${out_name}.log +define+SIM=1 \
    +fsdbpath=${FSDB_DIR}/${out_name}.fsdb -lca -kdb

# Inverter DCDL
set inc_name = inv_dcdl_viz
set out_name = inv_dcdl
echo "--- ${out_name} ---"
cd $SIM_DIR && rm -rf simv simv.daidir csrc >& /dev/null
vcs -f ${inc_name}.include +v2k -R +lint=all -sverilog -full64 \
    -timescale=1ps/1ps -debug_access+all \
    -l ${FSDB_DIR}/${out_name}.log +define+SIM=1 \
    +fsdbpath=${FSDB_DIR}/${out_name}.fsdb -lca -kdb

# Conditional inverter DCDL (different output behavior due to XNOR)
set inc_name = inv_dcdl_cond_viz
set out_name = inv_dcdl_cond
echo "--- ${out_name} ---"
cd $SIM_DIR && rm -rf simv simv.daidir csrc >& /dev/null
vcs -f ${inc_name}.include +v2k -R +lint=all -sverilog -full64 \
    -timescale=1ps/1ps -debug_access+all \
    -l ${FSDB_DIR}/${out_name}.log +define+SIM=1 \
    +fsdbpath=${FSDB_DIR}/${out_name}.fsdb -lca -kdb

# NAND DCDL top (shift register interface — different from inv DCDLs)
set inc_name = nand_dcdl_top_viz
set out_name = nand_dcdl
echo "--- ${out_name} ---"
cd $SIM_DIR && rm -rf simv simv.daidir csrc >& /dev/null
vcs -f ${inc_name}.include +v2k -R +lint=all -sverilog -full64 \
    -timescale=1ps/1ps -debug_access+all \
    -l ${FSDB_DIR}/${out_name}.log +define+SIM=1 \
    +fsdbpath=${FSDB_DIR}/${out_name}.fsdb -lca -kdb

# Glitch-free DCDL (registered Q — different from basic inv DCDLs)
set inc_name = inv_dcdl_glitch_free_viz
set out_name = inv_dcdl_glitch_free
echo "--- ${out_name} ---"
cd $SIM_DIR && rm -rf simv simv.daidir csrc >& /dev/null
vcs -f ${inc_name}.include +v2k -R +lint=all -sverilog -full64 \
    -timescale=1ps/1ps -debug_access+all \
    -l ${FSDB_DIR}/${out_name}.log +define+SIM=1 \
    +fsdbpath=${FSDB_DIR}/${out_name}.fsdb -lca -kdb

# -- Clean up sim artifacts ------------------------------------------

cd $SIM_DIR && rm -rf simv simv.daidir csrc >& /dev/null

# -- CONVERT FSDB to VCD --------------------------------------------

echo ""
echo "========================================"
echo " CONVERTING FSDB -> VCD"
echo "========================================"

foreach fsdb_file ( ${FSDB_DIR}/*.fsdb )
    set base = `basename $fsdb_file .fsdb`
    echo "  ${base}.fsdb -> ${base}.vcd"
    $FSDB2VCD $fsdb_file -o ${VCD_DIR}/${base}.vcd >& /dev/null
end

# -- GENERATE GIFs --------------------------------------------------

echo ""
echo "========================================"
echo " GENERATING GIFs"
echo "========================================"

python3 ${VIZ_DIR}/scripts/generate_gifs.py $VCD_DIR $GIF_DIR

# -- SUMMARY ---------------------------------------------------------

echo ""
echo "========================================"
echo " DONE"
echo "========================================"

set gif_count = `ls -1 ${GIF_DIR}/*.gif |& wc -l`
echo "GIFs generated: $gif_count"
echo "Location: $GIF_DIR"
