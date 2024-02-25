# -*- coding: utf-8 -*-

import random


def choose_random_page():
    pages = [

        '/restful/products',
        '/restful/products/4'
    ]

    return random.choice(pages)