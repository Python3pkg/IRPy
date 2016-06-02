#!/usr/bin/python
from collections import defaultdict
import uuid

#Handle your execution stack
d_path = defaultdict(lambda: [None])
d_last_caller = defaultdict(lambda: None)

def genealogy(obj, _node, direction, inclusif=False):
    """Return the genealogy of a _node.
       Direction is $parents or $children, recurse accordingly"""

    def sap(_node, direction, visited=None):
        if visited is None:
            visited = set()

        visited.add(_node)
        try:
            s = getattr(obj, "{0}_{1}".format(_node, direction))
        except AttributeError:
            s = set()

        for next_ in s - visited:
            sap(next_, direction, visited)

        return visited - set([None])

    s = sap(_node, direction)
    if not inclusif:
        s = s - set([_node])

    return s


def appendattr(obj, name, value):
    try:
        s = getattr(obj, name)
    except AttributeError:
        setattr(obj, name, set([value]))
    else:
        setattr(obj, name, set([value]) | s)


def sibling_coherence(obj, _node):
    """_node have changed, is now coherent. Reflect this fact on is sibling"""
    visited = set()

    for sibling in getattr(obj, "%s_incoherent" % (_node)):
        if sibling not in visited:
            for _child in genealogy(obj, sibling, "children", inclusif=True):
                _incoherent_child = "%s_incoherent" % (_child)
                if hasattr(obj, _incoherent_child):
                    s = getattr(obj, _incoherent_child) - set([sibling])
                    if not s:
                        delattr(obj, _incoherent_child)
                    else:
                        setattr(obj, _incoherent_child, s)

            visited.add(_child)


#  _                              
# | \  _   _  _  ._ _. _|_  _  ._ 
# |_/ (/_ (_ (_) | (_|  |_ (_) |  
#
class lazy_property(object):
    """
    My little Property
    My little Property
    My little Property...  friend
    """

    def __init__(self, provider, leaf_node=None, immutable=True):
        """Provider: If a function who will be used to compute the node
           leaf_node: If the name of the node
           immutable: If immutable is set you cannot set the node"""

        self.provider = provider
        self.leaf_node = leaf_node
        self.immutable = immutable

        if not self.leaf_node:
            name = provider.__name__
        else:
            name = self.leaf_node

        node = "%s_%s" % (name, id(provider))
        self._node = "_%s" % (node)
        self.incoherent = "_%s_incoherent" % (node)

    def __get__(self, obj, objtype):
        "Get the value of the node and handle the genealogy"
        _caller = d_path[obj][-1]
        _node = self._node

        #Genealogy
        if _caller != d_last_caller[obj]:
            appendattr(obj, "%s_parents" % _node, _caller)
            appendattr(obj, "%s_children" % _caller, _node)
            d_last_caller[obj] = _caller

        #Get the value
        try:
            value = getattr(obj, _node)
        except AttributeError:

            try:
                i = getattr(obj, self.incoherent)
            except AttributeError:
                d_path[obj].append(_node)

                value = self.provider(obj)
                setattr(obj, _node, value)

                d_path[obj].pop()
            else:
                msg = "Node {0} have been removed from the tree by {1}"
                raise AttributeError, msg.format(self.node," ".join(i))

        return value

    def __set__(self, obj, value):
        """Set the value of the node
        But wait, leaves are "gradual typed" variable! Youpi!
        Idea borrowed from the-worst-programming-language-ever (http://bit.ly/13tc6XW)
        """

        _node = self._node

        if self.immutable:
            if self.leaf_node:
                self.leaf_node = False
            else:
                raise AttributeError, "Immutable Node {0}".format(self.node)

        try:
            cur_value = getattr(obj, _node)
        except AttributeError:
            cur_value = None
        finally:
            if cur_value != value:
                setattr(obj, _node, value)

                #Remove_ancestor_cache
                for _parent in genealogy(obj, _node, "parents"):
                    if hasattr(obj, _parent): delattr(obj, _parent)

                #Descendant are now incoherent;
                #cause of the get optimization, we need to remove there cache.
                for _child in genealogy(obj, _node, "children"):
                    appendattr(obj, "%s_incoherent" % (_child), _node)
                    if hasattr(obj, _child): delattr(obj, _child)

                #If this node was incoherent before, we need to do some genealogy stuff verify the status of is sibling.
                if hasattr(obj, "%s_incoherent" % (_node)):
                    sibling_coherence(obj, _node)


def lazy_property_mutable(provider):
    "Return a lazy_property mutable"
    return lazy_property(provider=provider, immutable=False)


def lazy_property_leaves(mutables=(), immutables=()):
    "Set to properties for the __init__ method"

    def leaf_decorator(func):
        def func_wrapper(self, *args, **kwargs):

            for node in set(immutables) | set(mutables):

                def provider(self):
                    return getattr(self, "_%s" % (node))

                p = lazy_property(provider=provider,
                                  leaf_node=node,
                                  immutable=node in immutables)
                #If this ugly? Yeah... Is this an issue? I don't really know
                setattr(self.__class__, node, p)

            return func(self, *args, **kwargs)

        return func_wrapper

    return leaf_decorator
