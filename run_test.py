#!/usr/bin/env python

from irpy import irp_node
from irpy import irp_node_mutable
from irpy import irp_leafs_mutable


def init_loggin():
    import logging

    logger = logging.getLogger()
    handler = logging.StreamHandler()

    str_ = '[%(relativeCreated)d ms] {%(pathname)s:%(lineno)d} %(levelname)s - %(message)s'
    formatter = logging.Formatter(str_)
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG)

class t_factory(object):
    """
    t(u(d1,d2),v(d3,d4),w(d5))
    where:
        t(x,y) = x + y + 4
        u(x,y) = x + y + 1
        v(x,y) = x + y + 2
        w(x)   = x + 3
    """

    @irp_leafs_mutable("d1")
    def __init__(self, d1, d2, d3, d4, d5):
        self.d1 = d1
        self.d2 = d2
        self.d3 = d3
        self.d4 = d4
        self.d5 = d5

    @irp_node
    def t(self):
        return self.u1 + self.v + 4

    @irp_node
    def u1(self):
        return self.fu(self.d1, self.d2)

    @irp_node
    def v(self):
        return self.u2 + self.w + 2

    @irp_node
    def u2(self):
        return self.fu(self.d3, self.d4)

    @irp_node
    def w(self):
        return self.d5 + 3

    def fu(self, x, y):
        return x + y + 1


if __name__ == '__main__':

    init_loggin()

    F = t_factory(1, 5, 8, 10, 7)
    #Show the dynamic resolution of node
    assert (F.t == 42)
    #Show the lazy evaluation
    assert (F.t == 42)

    #Show the coherence and mutability of tree
    F.d1 = 2
    assert (F.t == 43)
