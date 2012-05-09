/*****************************************************************************
 * AlignmentExtractor.java
 *****************************************************************************
 * $Id: AlignmentExtractor.java, v 20110724
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

class AlignmentRcd {
	String alignment;
	List<String> word_alignment;
	Vector source_token_id;
	Vector target_token_id;

	AlignmentRcd() {
		alignment = "";
		word_alignment = new Vector<String>();
		//word_alignment = new ArrayList<String>();
		source_token_id = new Vector();
		target_token_id = new Vector();
	}

	void extract_src_trgt_tokens(String s)
	{
		int pos = s.indexOf('-');
		if (pos >= 0) {
			source_token_id.add(Integer.parseInt(s.substring(0, pos)));
			target_token_id.add(Integer.parseInt(s.substring(pos+1)));
		}
	}
	
	void addAlignment(String s) {
		alignment = s;
		StringTokenizer st = new StringTokenizer(s);
		while (st.hasMoreTokens()){
			String w_alignment = st.nextToken();
			word_alignment.add(w_alignment);
			extract_src_trgt_tokens(w_alignment);
		}
	}

	int getNumWordAlignments() { return word_alignment.size(); }
}

class AlignmentExtractor{
	File f;

	AlignmentExtractor (String fileName) {
		f = new File(fileName);
	}

	public List<AlignmentRcd> read() throws Exception {
		List<AlignmentRcd> list = new Vector<AlignmentRcd>();
		FileReader fr = null;
		BufferedReader br = null;
		int pos, endpos;

		fr = new FileReader(f);
		br = new BufferedReader(fr);
		String line = null;
		AlignmentRcd ar = null;

		while ((line = br.readLine()) != null)
		{
			if (ar != null) list.add(ar);
			ar = new AlignmentRcd();
			ar.addAlignment(line);
		}
		// Add the last tuple
		list.add(ar);

		br.close();
		fr.close();

		return list;
	}
}
