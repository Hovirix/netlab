from __future__ import annotations

import ipaddress
import re
from typing import Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class RouterConfig(BaseModel):
    """Router deployment target."""

    model_config = ConfigDict(extra="forbid")

    host: str = Field(min_length=1)
    user: str = Field(min_length=1)
    port: int = Field(ge=1, le=65535)

    @field_validator("host")
    @classmethod
    def validate_host(cls, value: str) -> str:
        try:
            ipaddress.ip_address(value)
        except ValueError:
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]", value):
                msg = "host must be an IP address or DNS hostname"
                raise ValueError(msg) from None
        return value


class BridgeVlan(BaseModel):
    """Switch VLAN membership for a bridge device."""

    model_config = ConfigDict(extra="forbid")

    id: int = Field(ge=1, le=4094)
    ports: list[str] = Field(min_length=1)

    @field_validator("ports")
    @classmethod
    def validate_ports(cls, value: list[str]) -> list[str]:
        for port in value:
            if not re.fullmatch(r"[A-Za-z0-9_.-]+(?::(?:t|u\*))?", port):
                msg = f"invalid bridge VLAN port membership: {port}"
                raise ValueError(msg)
        return value


class BridgeConfig(BaseModel):
    """OpenWrt bridge device and switch VLANs."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1)
    ports: list[str] = Field(min_length=1)
    vlans: list[BridgeVlan] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_unique_vlans(self) -> Self:
        vlan_ids = [vlan.id for vlan in self.vlans]
        if len(vlan_ids) != len(set(vlan_ids)):
            msg = "bridge VLAN IDs must be unique"
            raise ValueError(msg)
        return self


class NetworkInterface(BaseModel):
    """Layer-3 router interface backed by a bridge VLAN."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1)
    vlan: int = Field(ge=1, le=4094)
    address: str
    dns: str | None = None
    dhcp: bool = False

    @field_validator("address")
    @classmethod
    def validate_address(cls, value: str) -> str:
        ipaddress.ip_interface(value)
        return value

    @field_validator("dns")
    @classmethod
    def validate_dns(cls, value: str | None) -> str | None:
        if value is not None:
            ipaddress.ip_address(value)
        return value


class Wan6Config(BaseModel):
    """DHCPv6 uplink settings for MAP-E."""

    model_config = ConfigDict(extra="forbid")

    clientid: str = Field(min_length=1)


class WireGuardConfig(BaseModel):
    """Router WireGuard interface settings; keys remain in SOPS secrets."""

    model_config = ConfigDict(extra="forbid")

    listen_port: int = Field(ge=1, le=65535)
    addresses: list[str] = Field(min_length=1)

    @field_validator("addresses")
    @classmethod
    def validate_addresses(cls, value: list[str]) -> list[str]:
        for address in value:
            ipaddress.ip_interface(address)
        return value


class NetworkConfig(BaseModel):
    """Router network topology from config/default.yml."""

    model_config = ConfigDict(extra="forbid")

    bridge: BridgeConfig
    interfaces: list[NetworkInterface] = Field(min_length=1)
    wan6: Wan6Config
    wireguard: WireGuardConfig

    @model_validator(mode="after")
    def validate_interface_vlans(self) -> Self:
        bridge_vlans = {vlan.id for vlan in self.bridge.vlans}
        for interface in self.interfaces:
            if interface.vlan not in bridge_vlans:
                msg = f"interface {interface.name} references undefined VLAN {interface.vlan}"
                raise ValueError(msg)
        return self
