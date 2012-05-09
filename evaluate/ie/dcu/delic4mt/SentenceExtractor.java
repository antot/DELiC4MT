/*****************************************************************************
 * SentenceExtractor.java
 *****************************************************************************
 * $Id: SentenceExtractor.java, v 20110724
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

class Sentence {
	String sentence;
	Vector<String> word;
	
	Sentence () {
		sentence = null;
		word = new Vector<String>();
	}

	void addSentence(String s) {
		sentence = s;
		StringTokenizer st = new StringTokenizer(s);
		while (st.hasMoreTokens()){
			String token = st.nextToken();
			word.add(token);
		}
	}

	int getNumOfWords() { return word.size(); }
}

class SentenceExtractor{
	
	static File f;

	SentenceExtractor (String fileName) {
		f = new File(fileName);
	}

	public static List<Sentence> read() throws Exception {
		List<Sentence> list = new Vector<Sentence>();
		FileReader fr = null;
		BufferedReader br = null;
		int pos, endpos;

		fr = new FileReader(f);
		br = new BufferedReader(fr);
		String line = null;
		Sentence sen = null;

		while ((line = br.readLine()) != null)
		{
			if (sen != null) list.add(sen);
			sen = new Sentence();
			sen.addSentence(line);
		}
		// Add the last tuple
		list.add(sen);

		br.close();
		fr.close();

		return list;
	}
}
