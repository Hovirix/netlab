set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

validate:
	./scripts/validate.sh

render:
	./scripts/render.sh

build:
	./scripts/build.sh

clean:
	rm -rf build
