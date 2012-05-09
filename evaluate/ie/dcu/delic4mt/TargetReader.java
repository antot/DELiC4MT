/*****************************************************************************
 * TargetReader.java
 *****************************************************************************
 * $Id: TargetReader.java, v 20110724
 *****************************************************************************
 * Copyright (C) 2011,
 * Sudip Kumar Naskar, Dublin City University
 * snaskar at computing dot dcu dot ie
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111, USA.
 *****************************************************************************/

package ie.dcu.delic4mt;
import java.util.*;
import java.io.*;

class TargetRcd {
	List<String> targets;

	TargetRcd() { targets = new Vector<String>(); }

	void addTarget(String s) {
		targets.add(s);
	}

	int getNumRoles() { return targets.size()-1; }

	public String toString() {
		StringBuffer buff = new StringBuffer();
		buff.append("[");
		for (Iterator<String> iter = targets.iterator(); iter.hasNext(); ) {
			buff.append(iter.next());
			buff.append(", ");
		}
		buff.append("]");
		return buff.toString();
	}

	int getEventSentenceId() {
		String event = targets.get(0);
		int pos = event.indexOf('_');
		if (pos >= 0) {
			String sentenceId = event.substring(0, pos);
			return Integer.parseInt(sentenceId);
		}
		return -1;
	}

	int getEventTokenId() {
		String event = targets.get(0);
		int pos = event.indexOf('_');
		if (pos >= 0) {
			String sentenceId = event.substring(pos+1);
			return Integer.parseInt(sentenceId);
		}
		return -1;
	}

	int getRoleSentenceId(int i) {
		String event = targets.get(i+1);
		int pos = event.indexOf('_');
		if (pos >= 0) {
			String sentenceId = event.substring(0, pos);
			return Integer.parseInt(sentenceId);
		}
		return -1;
	}

	int getRoleTokenId(int i) {
		String event = targets.get(i+1);
		int pos = event.indexOf('_');
		if (pos >= 0) {
			String sentenceId = event.substring(pos+1);
			return Integer.parseInt(sentenceId);
		}
		return -1;
	}
}

class TargetReader {
	File f;

	TargetReader(String fileName) {
		f = new File(fileName);
	}

	public List<TargetRcd> read() throws Exception {
		List<TargetRcd> list = new Vector<TargetRcd>();
		FileReader fr = null;
		BufferedReader br = null;
		int pos, endpos;

		fr = new FileReader(f);
		br = new BufferedReader(fr);
		String line = null;
		TargetRcd tr = null;

		while ((line = br.readLine()) != null)
		{
			if (line.indexOf("event eid=") >= 0)
			{
				if (tr != null) list.add(tr);
				tr = new TargetRcd();
			}
			String pattern = "target=\"t";
			String target = "";
			pos = line.indexOf(pattern);
			if (pos < 0) continue;

			pos = pos + pattern.length();
			if (pos < line.length())
			{
				endpos = line.indexOf('"', pos);
				target = line.substring(pos, endpos);
				tr.addTarget(target);
			}
		}
		// Add the last tuple
		list.add(tr);

		br.close();
		fr.close();

		return list;
	}

	/*public static void main(String[] args) {
		if (args.length < 1) {
			System.err.println("usage: java TargetReader <filename>");
			System.exit(1);
		}
		try {
			TargetReader targetReader = new TargetReader(args[0]);
			List<TargetRcd> list = targetReader.read();

			for (Iterator<TargetRcd> iter = list.iterator(); iter.hasNext(); ) {
				TargetRcd t = iter.next();
				System.out.println(t.getEventSentenceId() + ", " + t.getEventTokenId());
			}
		}
		catch (Exception ex) {
			ex.printStackTrace();
		}
	}*/
}
