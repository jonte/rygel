/*
 * Copyright (C) 2009 Nokia Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

using GUPnP;

public enum Rygel.LogicalOperator {
    AND,
    OR
}

/**
 * Represents a SearchExpression tree.
 */
public abstract class Rygel.SearchExpression<G,H,I> {
    public G op; // Operator

    public H operand1;
    public I operand2;

    public bool fullfills (MediaObject media_object) {
        return true;
    }

    public abstract string to_string ();
}

public class Rygel.AtomicExpression :
              Rygel.SearchExpression<SearchCriteriaOp,string,string> {
    public override string to_string () {
        return "%s %d %s".printf (this.operand1, this.op, this.operand2);
    }
}

public class Rygel.LogicalExpression :
              Rygel.SearchExpression<LogicalOperator,
                                     SearchExpression,
                                     SearchExpression> {
    public override string to_string () {
        return "(%s %d %s)".printf (this.operand1.to_string (),
                                    this.op,
                                    this.operand2.to_string ());
    }
}
