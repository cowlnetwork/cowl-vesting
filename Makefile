PINNED_TOOLCHAIN := $(shell cat contract/rust-toolchain)

prepare:
	rustup install ${PINNED_TOOLCHAIN} # Ensure the correct nightly is installed
	rustup target add wasm32-unknown-unknown
	rustup component add clippy --toolchain ${PINNED_TOOLCHAIN}
	rustup component add rustfmt --toolchain ${PINNED_TOOLCHAIN}
	rustup component add rust-src --toolchain ${PINNED_TOOLCHAIN}

.PHONY:	build-contract
build-contract:
	cd contract && RUSTFLAGS="-C target-cpu=mvp" cargo build --release --target wasm32-unknown-unknown -Z build-std=std,panic_abort -p cowl-vesting
	wasm-strip target/wasm32-unknown-unknown/release/cowl_vesting.wasm

setup-test: build-contract copy-wasm
	$(eval LATEST_WASM_CEP18=$(shell curl -s https://api.github.com/repos/cowlnetwork/cep18/releases/latest | jq -r '.assets[] | select(.name=="cowl-cep18-wasm.tar.gz") | .browser_download_url'))

	@if [ -z "$(LATEST_WASM_CEP18)" ]; then \
		echo "Error: cowl-cep18 WASM URL is empty."; \
		exit 1; \
	fi

	@echo "Downloading and extracting latest cowl-cep18 WASM..."
	curl -L $(LATEST_WASM_CEP18) -o cowl-cep18-wasm.tar.gz && \
	tar -xvzf cowl-cep18-wasm.tar.gz -C tests/wasm && \
	rm cowl-cep18-wasm.tar.gz

copy-wasm:
	mkdir -p tests/wasm
	cp ./target/wasm32-unknown-unknown/release/cowl_vesting.wasm tests/wasm

test: setup-test test-dev

test-dev:
	cd tests && cargo test

clippy:
	cd contract && cargo clippy --bins --target wasm32-unknown-unknown -Z build-std=std,panic_abort -- -D warnings
	cd contract && cargo clippy --lib --target wasm32-unknown-unknown -Z build-std=std,panic_abort -- -D warnings
	cd contract && cargo clippy --lib --target wasm32-unknown-unknown -Z build-std=std,panic_abort --no-default-features -- -D warnings
	cd tests && cargo clippy --all-targets -- -D warnings

check-lint: clippy
	cd contract && cargo fmt -- --check
	cd tests && cargo +$(PINNED_TOOLCHAIN) fmt -- --check

format:
	cd contract && cargo fmt
	cd tests && cargo +$(PINNED_TOOLCHAIN) fmt

clean:
	cd contract && cargo clean
	cd tests && cargo clean
	rm -rf tests/wasm
