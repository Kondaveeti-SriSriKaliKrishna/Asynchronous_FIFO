vlib work
vlog asynchronous_fifo_tb.v
vsim tb +testname=basic
add wave -position insertpoint sim:/tb/*
run -all


