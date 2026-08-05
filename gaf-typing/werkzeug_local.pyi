"""Editor-only type stub for ``werkzeug.local`` (werkzeug 0.11).

Purpose
-------
``LocalProxy.__getattr__`` is written as::

    def __getattr__(self, name):
        if name == "__members__":
            return dir(self._get_current_object())     # -> list[str]
        return getattr(self._get_current_object(), name)   # -> Any

Pyright unions both branches into ``list[str] | Any`` and then reports every
attribute access against the ``list[str]`` arm. Because ``flask.current_app``,
``flask.g`` and ``flask.request`` are all ``LocalProxy`` instances, that single
inference produced 1804 of the 2383 diagnostics in ``rest/api`` -- 76% of the
noise, all of it spurious.

This stub narrows the return to ``Any``, which is what the proxy actually gives
you at runtime for every name except the ``__members__`` special case.

Measured over all of ``rest/api``: 263 errors -> 24, 2120 warnings -> 316. One
genuine finding surfaced that Any had been hiding
(challenges_api.py:373 returns a 1-tuple from a function annotated
``-> flask.Response``).

Scope
-----
Installed into the api311 virtualenv's site-packages, NOT the repo. Git never
sees it, and ``arc lint`` never sees it either -- its mypy runs in a separate
Docker image with its own dependencies. Only the editor language server reads
this file. A ``pip install``/reinstall of werkzeug removes it; rerun
:GafTypingApply.

Generated with ``basedpyright --createstub werkzeug.local``, then: narrowed
``__getattr__``, and added the imports the generator referenced but omitted
(``Any``, ``Callable``, ``methodcaller``, ``_Wrapped``, ``LiteralString``,
``greenlet``).

Managed by ~/.config/nvim/gaf-typing/. See docs/inter-service-typing.md.
"""

from operator import methodcaller
from typing import Any, Callable

from werkzeug._compat import PY2, implements_bool

_Wrapped = Any
LiteralString = str
greenlet = Any

"""
    werkzeug.local
    ~~~~~~~~~~~~~~

    This module implements context-local objects.

    :copyright: (c) 2014 by the Werkzeug Team, see AUTHORS for more details.
    :license: BSD, see LICENSE for more details.
"""
def release_local(local) -> None:
    """Releases the contents of the local for the current context.
    This makes it possible to use locals without a manager.

    Example::

        >>> loc = Local()
        >>> loc.foo = 42
        >>> release_local(loc)
        >>> hasattr(loc, 'foo')
        False

    With this function one can release :class:`Local` objects as well
    as :class:`LocalStack` objects.  However it is not possible to
    release data held by proxies that way, one always has to retain
    a reference to the underlying local object in order to be able
    to release it.

    .. versionadded:: 0.6.1
    """
    ...

class Local:
    __slots__ = ...
    def __init__(self) -> None:
        ...
    
    def __iter__(self):
        ...
    
    def __call__(self, proxy) -> LocalProxy:
        """Create a proxy for a name."""
        ...
    
    def __release_local__(self) -> None:
        ...
    
    def __getattr__(self, name):
        ...
    
    def __setattr__(self, name, value) -> None:
        ...
    
    def __delattr__(self, name) -> None:
        ...
    


class LocalStack:
    """This class works similar to a :class:`Local` but keeps a stack
    of objects instead.  This is best explained with an example::

        >>> ls = LocalStack()
        >>> ls.push(42)
        >>> ls.top
        42
        >>> ls.push(23)
        >>> ls.top
        23
        >>> ls.pop()
        23
        >>> ls.top
        42

    They can be force released by using a :class:`LocalManager` or with
    the :func:`release_local` function but the correct way is to pop the
    item from the stack after using.  When the stack is empty it will
    no longer be bound to the current context (and as such released).

    By calling the stack without arguments it returns a proxy that resolves to
    the topmost item on the stack.

    .. versionadded:: 0.6.1
    """
    def __init__(self) -> None:
        ...
    
    def __release_local__(self) -> None:
        ...
    
    __ident_func__ = ...
    def __call__(self) -> LocalProxy:
        ...
    
    def push(self, obj) -> Any | list[Any]:
        """Pushes a new item to the stack"""
        ...
    
    def pop(self) -> Any | None:
        """Removes the topmost item from the stack, will return the
        old value or `None` if the stack was already empty.
        """
        ...
    
    @property
    def top(self) -> None:
        """The topmost item on the stack.  If the stack is empty,
        `None` is returned.
        """
        ...
    


class LocalManager:
    """Local objects cannot manage themselves. For that you need a local
    manager.  You can pass a local manager multiple locals or add them later
    by appending them to `manager.locals`.  Every time the manager cleans up,
    it will clean up all the data left in the locals for this context.

    The `ident_func` parameter can be added to override the default ident
    function for the wrapped locals.

    .. versionchanged:: 0.6.1
       Instead of a manager the :func:`release_local` function can be used
       as well.

    .. versionchanged:: 0.7
       `ident_func` was added.
    """
    def __init__(self, locals=..., ident_func=...) -> None:
        ...
    
    def get_ident(self) -> greenlet | int:
        """Return the context identifier the local objects use internally for
        this context.  You cannot override this method to change the behavior
        but use it to link other context local objects (such as SQLAlchemy's
        scoped sessions) to the Werkzeug locals.

        .. versionchanged:: 0.7
           You can pass a different ident function to the local manager that
           will then be propagated to all the locals passed to the
           constructor.
        """
        ...
    
    def cleanup(self) -> None:
        """Manually clean up the data in the locals for this context.  Call
        this at the end of the request or use `make_middleware()`.
        """
        ...
    
    def make_middleware(self, app) -> Callable[..., ClosingIterator]:
        """Wrap a WSGI application so that cleaning up happens after
        request end.
        """
        ...
    
    def middleware(self, func) -> _Wrapped:
        """Like `make_middleware` but for decorating functions.

        Example usage::

            @manager.middleware
            def application(environ, start_response):
                ...

        The difference to `make_middleware` is that the function passed
        will have all the arguments copied from the inner application
        (name, docstring, module).
        """
        ...
    
    def __repr__(self) -> str:
        ...
    


@implements_bool
class LocalProxy:
    """Acts as a proxy for a werkzeug local.  Forwards all operations to
    a proxied object.  The only operations not supported for forwarding
    are right handed operands and any kind of assignment.

    Example usage::

        from werkzeug.local import Local
        l = Local()

        # these are proxies
        request = l('request')
        user = l('user')


        from werkzeug.local import LocalStack
        _response_local = LocalStack()

        # this is a proxy
        response = _response_local()

    Whenever something is bound to l.user / l.request the proxy objects
    will forward all operations.  If no object is bound a :exc:`RuntimeError`
    will be raised.

    To create proxies to :class:`Local` or :class:`LocalStack` objects,
    call the object as shown above.  If you want to have a proxy to an
    object looked up by a function, you can (as of Werkzeug 0.6.1) pass
    a function to the :class:`LocalProxy` constructor::

        session = LocalProxy(lambda: get_current_request().session)

    .. versionchanged:: 0.6.1
       The class can be instantiated with a callable as well now.
    """
    __slots__ = ...
    def __init__(self, local, name=...) -> None:
        ...
    
    @property
    def __dict__(self) -> Any:
        ...
    
    def __repr__(self) -> LiteralString | str:
        ...
    
    def __bool__(self) -> bool:
        ...
    
    def __unicode__(self) -> str:
        ...
    
    def __dir__(self) -> list[str] | list[Any]:
        ...
    
    def __getattr__(self, name) -> Any:
        ...
    
    def __setitem__(self, key, value) -> None:
        ...
    
    def __delitem__(self, key) -> None:
        ...
    
    if PY2:
        __getslice__ = ...
        def __setslice__(self, i, j, seq) -> None:
            ...
        
        def __delslice__(self, i, j) -> None:
            ...
        
    __setattr__ = ...
    __delattr__ = ...
    __str__ = ...
    __lt__ = ...
    __le__ = ...
    __eq__ = ...
    __ne__ = ...
    __gt__ = ...
    __ge__ = ...
    __cmp__ = ...
    __hash__ = ...
    __call__ = ...
    __len__ = ...
    __getitem__ = ...
    __iter__ = ...
    __contains__ = ...
    __add__ = ...
    __sub__ = ...
    __mul__ = ...
    __floordiv__ = ...
    __mod__ = ...
    __divmod__ = ...
    __pow__ = ...
    __lshift__ = ...
    __rshift__ = ...
    __and__ = ...
    __xor__ = ...
    __or__ = ...
    __div__ = ...
    __truediv__ = ...
    __neg__ = ...
    __pos__ = ...
    __abs__ = ...
    __invert__ = ...
    __complex__ = ...
    __int__ = ...
    __long__ = ...
    __float__ = ...
    __oct__ = ...
    __hex__ = ...
    __index__ = ...
    __coerce__ = ...
    __enter__ = ...
    __exit__ = ...
    __radd__ = ...
    __rsub__ = ...
    __rmul__ = ...
    __rdiv__ = ...
    if PY2:
        __rtruediv__ = ...
    else:
        __rtruediv__ = ...
    __rfloordiv__ = ...
    __rmod__ = ...
    __rdivmod__ = ...
    __copy__ = ...
    __deepcopy__ = ...


