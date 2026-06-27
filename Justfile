set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
	just --list

validate:
	./scripts/validate.sh

render:
	./scripts/render.sh

build:
	./scripts/validate.sh
	./scripts/render.sh
	./scripts/build.sh

update:
	./scripts/update.sh

deploy:
	./scripts/deploy.sh

clean:
	rm -rf build
