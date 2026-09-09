NERDCTL := sudo nerdctl
TAG ?= latest

.PHONY: all nvidia-smi pytorch-cuda apply-nvidia-smi apply-pytorch-cuda delete-nvidia-smi delete-pytorch-cuda

all: nvidia-smi pytorch-cuda

nvidia-smi:
	$(NERDCTL) build -t nvidia-smi:$(TAG) --target nvidia-smi .

pytorch-cuda:
	$(NERDCTL) build -t pytorch-cuda:$(TAG) --target pytorch .

apply-nvidia-smi:
	kubectl apply -f nvidia-smi.yaml

apply-pytorch-cuda:
	kubectl apply -f pytorch-cuda.yaml

delete-nvidia-smi:
	kubectl delete -f nvidia-smi.yaml

delete-pytorch-cuda:
	kubectl delete -f pytorch-cuda.yaml
