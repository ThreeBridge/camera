PROJECT_NAME := camera
PROJECT_DIR  := $(PROJECT_NAME)

$(PROJECT_DIR):
	@vivado -mode batch -source create.tcl 

create_project: $(PROJECT_DIR)

implement: $(PROJECT_DIR)
	@vivado -mode batch -source implement.tcl -tclargs $(PROJECT_NAME) $(PROJECT_DIR)

all: implement

clean:
	@rm -rf .Xil vivado_* *.log *.jou

allclean: clean
	@rm -rf $(PROJECT_DIR)

.PHONY: all create_project clean
