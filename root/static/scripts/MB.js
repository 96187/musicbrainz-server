/* Copyright (C) 2009 Oliver Charles

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

'use strict';

// Namespaces
var MB = {
    // Classes, common controls used throughout MusicBrainz
    Control: {},

    // Utility functions
    utility: {},

    // Predicates to be used in $.grep
    predicate: {},

    // Hold translated text strings
    text: {},

    // Hold any URLs that controls might use
    url: {}
};

MB.Object = function () {
    var self = {};

    var parent = function (name) {
        var that = this;
        var method = this[name];

        return function () {
            return method.apply (that, arguments);
        };
    };

    self.parent = parent;

    return self;
};

