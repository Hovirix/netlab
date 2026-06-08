#!/usr/bin/env python3
import argparse
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

from ruamel.yaml import YAML


def run(command, *, input_text=None):
    try:
        return subprocess.run(
            command,
            input=input_text,
            text=True,
            check=True,
            capture_output=True,
        ).stdout
    except FileNotFoundError:
        print(f"Error: required command not found: {command[0]}", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as error:
        stderr = error.stderr.strip()
        if stderr:
            print(stderr, file=sys.stderr)
        print(f"Error: command failed: {' '.join(command)}", file=sys.stderr)
        sys.exit(error.returncode)


def wg_genkey():
    return run(["wg", "genkey"]).strip()


def wg_pubkey(private_key):
    return run(["wg", "pubkey"], input_text=f"{private_key}\n").strip()


def wg_genpsk():
    return run(["wg", "genpsk"]).strip()


def repo_root():
    root = os.environ.get("NETLAB_ROOT")
    if root:
        return Path(root).resolve()

    output = run(["git", "rev-parse", "--show-toplevel"])
    return Path(output.strip()).resolve()


def load_yaml(secret_path):
    plaintext = run(["sops", "-d", str(secret_path)])
    yaml = YAML()
    data = yaml.load(plaintext)
    if not isinstance(data, dict):
        raise ValueError("network secret must decrypt to a YAML mapping")
    return yaml, data


def wireguard_config(data):
    wireguard = data.get("wireguard")
    if not isinstance(wireguard, dict):
        raise ValueError("missing wireguard mapping")

    server = wireguard.get("server")
    if not isinstance(server, dict):
        raise ValueError("missing wireguard.server mapping")

    peers = wireguard.get("peers")
    if not isinstance(peers, list):
        raise ValueError("missing wireguard.peers list")

    return wireguard, server, peers


def endpoint_from_config(wireguard, server, cli_endpoint):
    endpoint = cli_endpoint or wireguard.get("endpoint") or server.get("endpoint")
    if not endpoint:
        raise ValueError("missing WireGuard endpoint; add wireguard.endpoint or use --endpoint")
    return str(endpoint)


def selected_peers(peers, names, all_peer_psks):
    if all_peer_psks:
        return peers

    selected = []
    for name in names:
        matches = [peer for peer in peers if peer.get("description") == name]
        if not matches:
            raise ValueError(f"peer not found: {name}")
        if len(matches) > 1:
            raise ValueError(f"peer description is ambiguous: {name}")
        selected.append(matches[0])
    return selected


def single_peer(peers, name):
    matches = [peer for peer in peers if peer.get("description") == name]
    if not matches:
        raise ValueError(f"peer not found: {name}")
    if len(matches) > 1:
        raise ValueError(f"peer description is ambiguous: {name}")
    return matches[0]


def render_client_config(peer_private_key, router_public_key, preshared_key, address, endpoint):
    return f"""[Interface]
PrivateKey = {peer_private_key}
Address = {address}
DNS = 10.10.0.1

[Peer]
PublicKey = {router_public_key}
PresharedKey = {preshared_key}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = {endpoint}
PersistentKeepalive = 25
"""


def show_qr(config):
    print(run(["qrencode", "-t", "ANSIUTF8"], input_text=config))


def write_encrypted(secret_path, yaml, data):
    secret_dir = secret_path.parent
    plain_fd, plain_name = tempfile.mkstemp(
        prefix=".network.rotate.", suffix=".yaml", dir=secret_dir
    )
    encrypted_fd, encrypted_name = tempfile.mkstemp(
        prefix=".network.rotate.", suffix=".sops.yaml", dir=secret_dir
    )
    os.close(encrypted_fd)

    plain_path = Path(plain_name)
    encrypted_path = Path(encrypted_name)

    try:
        os.fchmod(plain_fd, stat.S_IRUSR | stat.S_IWUSR)
        with os.fdopen(plain_fd, "w") as plain_file:
            yaml.dump(data, plain_file)

        encrypted = run(
            [
                "sops",
                "--encrypt",
                "--input-type",
                "yaml",
                "--output-type",
                "yaml",
                "--filename-override",
                str(secret_path),
                str(plain_path),
            ]
        )
        encrypted_path.write_text(encrypted)

        decrypted = run(["sops", "-d", str(encrypted_path)])
        validated = yaml.load(decrypted)
        wireguard_config(validated)
        os.replace(encrypted_path, secret_path)
    finally:
        if plain_path.exists():
            plain_path.unlink()
        if encrypted_path.exists():
            encrypted_path.unlink()


def parse_args():
    parser = argparse.ArgumentParser(
        prog="rotate-secrets",
        description="Rotate WireGuard secrets in secrets/network.sops.yaml."
    )
    parser.add_argument(
        "--secret",
        type=Path,
        help="Path to network.sops.yaml. Defaults to $NETLAB_ROOT/secrets/network.sops.yaml.",
    )
    parser.add_argument(
        "--peer",
        action="append",
        default=[],
        help="Rotate the preshared key for a peer description. Repeatable.",
    )
    parser.add_argument(
        "--replace-peer",
        help="Generate a new peer keypair and preshared key for one peer description.",
    )
    parser.add_argument(
        "--endpoint",
        help="WireGuard endpoint for emitted client configs. Defaults to wireguard.endpoint.",
    )
    parser.add_argument(
        "--showconfig",
        action="store_true",
        help="Print the generated client config for --replace-peer.",
    )
    parser.add_argument(
        "--qr",
        action="store_true",
        help="Render the generated client config as an ANSI terminal QR code.",
    )
    parser.add_argument(
        "--all-peer-psks",
        action="store_true",
        help="Rotate preshared keys for all configured peers.",
    )
    parser.add_argument(
        "--server",
        action="store_true",
        help="Rotate the WireGuard server private key.",
    )
    parser.add_argument(
        "--confirm-disruptive",
        action="store_true",
        help="Required with --server because all clients need the new server public key.",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    peer_modes = [bool(args.peer), args.all_peer_psks, bool(args.replace_peer)]
    if sum(peer_modes) > 1:
        print(
            "Error: use only one of --peer, --all-peer-psks, or --replace-peer",
            file=sys.stderr,
        )
        return 2
    if not any(peer_modes) and not args.server:
        print(
            "Error: choose --peer, --all-peer-psks, --replace-peer, or --server",
            file=sys.stderr,
        )
        return 2
    if (args.showconfig or args.qr) and not args.replace_peer:
        print("Error: --showconfig and --qr require --replace-peer", file=sys.stderr)
        return 2
    if args.replace_peer and args.server:
        print("Error: --replace-peer cannot be combined with --server", file=sys.stderr)
        return 2
    if args.replace_peer and not (args.showconfig or args.qr):
        print(
            "Error: --replace-peer requires --showconfig or --qr",
            file=sys.stderr,
        )
        return 2
    if args.server and not args.confirm_disruptive:
        print("Error: --server requires --confirm-disruptive", file=sys.stderr)
        return 2

    secret_path = args.secret.resolve() if args.secret else repo_root() / "secrets/network.sops.yaml"
    if not secret_path.is_file():
        print(f"Error: secret file not found: {secret_path}", file=sys.stderr)
        return 1

    try:
        yaml, data = load_yaml(secret_path)
        wireguard, server, peers = wireguard_config(data)
        peers_to_rotate = selected_peers(peers, args.peer, args.all_peer_psks)
        peer_to_replace = single_peer(peers, args.replace_peer) if args.replace_peer else None
    except ValueError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    changed = []
    for peer in peers_to_rotate:
        description = peer.get("description", "<missing description>")
        peer["preshared_key"] = wg_genpsk()
        changed.append(f"wireguard.peers[{description}].preshared_key")

    client_config = None
    if peer_to_replace:
        try:
            endpoint = endpoint_from_config(wireguard, server, args.endpoint)
        except ValueError as error:
            print(f"Error: {error}", file=sys.stderr)
            return 1

        description = peer_to_replace.get("description", "<missing description>")
        address = peer_to_replace.get("allowed_ip")
        if not address:
            print(f"Error: peer missing allowed_ip: {description}", file=sys.stderr)
            return 1

        peer_private_key = wg_genkey()
        peer_public_key = wg_pubkey(peer_private_key)
        preshared_key = wg_genpsk()
        router_public_key = wg_pubkey(server["private_key"])

        peer_to_replace["public_key"] = peer_public_key
        peer_to_replace["preshared_key"] = preshared_key
        client_config = render_client_config(
            peer_private_key,
            router_public_key,
            preshared_key,
            address,
            endpoint,
        )
        changed.append(f"wireguard.peers[{description}].public_key")
        changed.append(f"wireguard.peers[{description}].preshared_key")

    new_server_public_key = None
    if args.server:
        private_key = wg_genkey()
        new_server_public_key = wg_pubkey(private_key)
        server["private_key"] = private_key
        changed.append("wireguard.server.private_key")

    if not changed:
        print("No changes selected.")
        return 0

    print()
    print("WireGuard secret rotation")
    print("=========================")
    print()
    print("Changes:")
    for field in changed:
        print(f"- {field}")

    if new_server_public_key:
        print()
        print(f"New server public key: {new_server_public_key}")
        print("Update every WireGuard client with this public key.")

    write_encrypted(secret_path, yaml, data)
    print()
    print(f"Updated {secret_path}")

    if client_config and (args.showconfig or args.qr):
        print()
        print("The generated client config contains private key material. Store it securely.")
    if client_config and args.showconfig:
        print()
        print("Client config")
        print("-------------")
        print()
        print(client_config)
    if client_config and args.qr:
        print()
        print("Client config QR")
        print("----------------")
        print()
        show_qr(client_config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
