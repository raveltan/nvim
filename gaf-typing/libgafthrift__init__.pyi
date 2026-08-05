"""Editor-only type stub for ``libgafthrift``.

Purpose
-------
``thrift_wrapper`` dispatches every RPC through ``__getattr__``, which returns
``functools.partial``. That makes each of the ~2000 inter-service calls in this
monorepo resolve to ``Any``: no completion, no argument checking, no go-to-
definition. The real signatures already exist in ``gaf_thrift-stubs/``; nothing
connected the wrapper to them.

This stub writes down the missing rule::

    thrift_wrapper(host, port, M) -> M.Client

so ``self.conns.projects_dao.projects_get(...)`` resolves to the generated
``Client`` method and is checked against it.

``thrift_wrapper`` is declared here as a function rather than a class. That is
deliberate: the equivalent generic-class form (``__new__`` returning a TypeVar)
is accepted by pyright but rejected by mypy, which gates ``arc lint``. The
function form is accepted by both. Nothing in the repo subclasses
``thrift_wrapper`` or calls ``isinstance`` against it, so nothing depends on it
being a class.

Maintenance
-----------
A ``.pyi`` shadows its module, so anything added to ``__init__.py`` stays
invisible here until this file is regenerated::

    basedpyright --createstub libgafthrift

Regenerating loses the edits below; ``:GafTypingApply`` reinstalls this vetted
copy instead. Generated stubs also reference names they never import, so a
regenerated file needs its imports repaired before it will pass mypy.

Managed by ~/.config/nvim/gaf-typing/. Untracked via .git/info/exclude.
See docs/inter-service-typing.md.
"""

import socket
import os
import sys
import warnings
import json
import logging
import itertools
import random
import traceback
import pkgutil
import threading
from enum import Enum
from typing import Any, Generic, Protocol, Self, TypeVar

import gaf_thrift

_RetAddress = Any

_I = TypeVar('_I')
import datetime
import uuid
import struct
import gaf_thrift.common.ttypes as common_types
import six
from enum import Enum
from functools import partial
from numbers import Number
from . import thriftfind
from thrift.transport import TSocket, TTransport
from thrift.transport.TTransport import TTransportException
from thrift.Thrift import TType
from thrift.protocol import TBinaryProtocol
from gaf_thrift.common.header.ttypes import Header
from gaf_thrift.errors.ttypes import Error, ErrorCode
from libgafthrift.tracing.utils import get_current_span_id, start_child
from prometheus_client import Counter
from six.moves import map
from collections.abc import Iterable
from collections.abc import Iterable

THRIFT_ATTEMPTS_SUCCESS = ...
THRIFT_ATTEMPTS_FAILURE = ...
if six.PY2:
    ...
else:
    ...
pool_enum_values = ...
if not sys.warnoptions:
    ...
def get_client_status(fd) -> tuple[Any, _RetAddress]:
    ...

def get_root_path(import_name) -> str:
    """
    Stolen from Flask.helpers:

    Returns the path to a package or cwd if that cannot be found.  This
    returns the path of a package or the folder that contains a module.
    """
    ...

class _ThriftApi(Protocol[_I]):
    """Structural type of a generated ``gaf_thrift.<service>.api`` module."""
    Client: type[_I]

def thrift_wrapper(host: str, port: int | Enum, client_class: _ThriftApi[_I],
                retries: int = ..., timeout: float = ..., logger=..., reporter=...,
                use_gevent: bool = ..., auth_key: str | None = ...) -> _I: ...

class ThriftEncoder(json.JSONEncoder):
    """Class for serialising thrift objects to JSON."""
    def encodeThriftStruct(self, obj) -> dict[Any, Any | list[str] | str | None]:
        """Encode Thrift Struct.

        - TODO: Cleanup T220848
        """
        ...
    
    def default(self, obj) -> list[Any] | str | dict[Any, Any | list[str] | str | None]:
        ...
    


class CompactThriftEncoder(json.JSONEncoder):
    """Class for serialising thrift objects to JSON.

    Unlike the default ThriftEncoder this class will strip any fields which have null values.
    """
    def encodeThriftStruct(self, obj) -> dict[Any, Any] | dict[Any, Any | list[str] | str | None]:
        """Encode Thrift Struct.

        - TODO: Cleanup T220848
        """
        ...
    
    def default(self, obj) -> list[Any] | str | dict[Any, Any] | dict[Any, Any | list[str] | str | None]:
        ...
    


class JsonThriftException(Exception):
    """Failed conversion of json to Thrift object."""
    def __init__(self, message, error=...) -> None:
        """Init function."""
        ...
    


def json_to_thrift(ttype, constructor, json, stack=...):
    """Converts a json object to a Thrift object.

    Really should be using something like TSimpleJSONProtocol, but
    sadly it's not good enough (e.g. have to act like fastbinary to do
    string/enum conv).

    Does almost the opposite of the ThriftEncoder above, but
    note that this takes an already decoded json object (i.e. all
    json variables here are really just nested dicts, etc.).

    :param ttype: Thrift TType (e.g. TType.I32, TType.STRUCT, ...)
    :param constructor: constructor for kind of TType (see thrift_spec)
                        (can be None if not applicable, or a tuple
                         if we're a LIST or similar)
    :param json: decoded JSON (i.e. in Python structures, NOT string)
    """
    ...

def construct_acl(acl_as_tuples) -> list[Any]:
    ...

def check_or_generate_request_id(request) -> Header | gaf_thrift.common.ttypes.Auth | gaf_thrift.auth.ttypes.Auth | None:
    ...

def get_extra_log_data(request, **kwargs) -> dict[str, Any]:
    ...

