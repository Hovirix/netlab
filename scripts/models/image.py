from __future__ import annotations

import re

from pydantic import BaseModel, ConfigDict, Field, field_validator


class OpenWrtImage(BaseModel):
    """OpenWrt ImageBuilder metadata from config/default.yml."""

    model_config = ConfigDict(extra="forbid")

    version: str
    target: str = Field(min_length=1)
    subtarget: str = Field(min_length=1)
    profile: str = Field(min_length=1)
    host_suffix: str = Field(min_length=1)
    packages: list[str] = Field(default_factory=list)
    imagebuilder_sha256: str

    @field_validator("version", mode="before")
    @classmethod
    def normalize_version(cls, value: object) -> str:
        return str(value)

    @field_validator("imagebuilder_sha256")
    @classmethod
    def validate_sha256(cls, value: str) -> str:
        if not re.fullmatch(r"[0-9a-f]{64}", value):
            msg = "imagebuilder_sha256 must be a lowercase 64-character hex digest"
            raise ValueError(msg)
        return value

    @property
    def imagebuilder_name(self) -> str:
        return (
            f"openwrt-imagebuilder-{self.version}-{self.target}-{self.subtarget}"
            f".{self.host_suffix}"
        )

    @property
    def imagebuilder_archive(self) -> str:
        return f"{self.imagebuilder_name}.tar.zst"

    @property
    def imagebuilder_url(self) -> str:
        return (
            f"https://downloads.openwrt.org/releases/{self.version}/targets/"
            f"{self.target}/{self.subtarget}/{self.imagebuilder_archive}"
        )
