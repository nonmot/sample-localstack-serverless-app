.PHONY: up down init plan apply destroy fmt build

up:
	docker compose up -d

down:
	docker compose down --remove-orphans

init:
	cd terraform && terraform init

apply:
	cd terraform && terraform apply

plan:
	cd terraform && terraform plan

destroy:
	cd terraform && terraform destroy

fmt:
	cd terraform && terraform fmt

build:
	cd frontend && pnpm build
