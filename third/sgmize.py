#! /usr/bin/env python

#-------------------------------------------------------------------------------
# This file is part of OpenMaTrEx: a marker-driven corpus-based machine
# translation system.
# 
# Copyright (c) 2004-2010 Dublin City University
# (c) 2004-2007 Steve Armstrong, Yvette Graham, Nano Gough, Declan Groves,
# Yanjun Ma, Nicolas Stroppa, John Tinsley, Andy Way, Bart Mellebeek
# (c) 2010 Sandipan Dandapat, Sergio Penkale
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#-------------------------------------------------------------------------------

import sys

(type_, name, srclang, trglang, docid, sysid) = sys.argv[1:7]
print "<" + type_ + "set setid=\"" + name + "\" srclang=\"" + srclang + "\" trglang=\"" + trglang + "\">"

j=1
for input_file_name in sys.argv[7:]:
    print "<DOC docid=\"" + docid + "\" sysid=\"" + sysid + str(j) + "\">"
    j+=1
    i=1
    input_file = open(input_file_name)
    for line in input_file:
        print "<seg id=\"" + str(i) + "\">"
        print line.strip()
        print "</seg>"
        i += 1
    print "</DOC>"
    input_file.close()

print "</" + type_ + "set>"
