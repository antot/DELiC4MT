/*****************************************************************************
 * KAFSentenceExtractor.java
 *****************************************************************************
 * $Id: KAFSentenceExtractor.java, v 20110724
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

class KAFToken {
	String token;
	
	KAFToken () {
		token = null;
	}

	void assignToken(String s) {
		token = s;
	}
}

class KAFSentence {
	String sentence;
	Vector<KAFToken> kaf_token;
	
	KAFSentence () {
		sentence = null;
		kaf_token = new Vector<KAFToken>();
	}

	void addToken(KAFToken t) {
		kaf_token.add(t);
	}

	int getNumOfTokens() { return kaf_token.size(); }
}

class KAFSentenceExtractor{
	
	static File f;

	KAFSentenceExtractor (String fileName) {
		f = new File(fileName);
	}

	public static List<KAFSentence> read() throws Exception {
		List<KAFSentence> list = new Vector<KAFSentence>();
		FileReader fr = null;
		BufferedReader br = null;
		int pos, endpos;

		fr = new FileReader(f);
		br = new BufferedReader(fr);
		String line = null;
		int sent_id = 0;
		String token = null;
		KAFSentence KAF_sen = null;
		KAFToken KAF_tkn = null;

		while ((line = br.readLine()) != null)
		{
			if (line.indexOf("<wf") == 0)
			{
				String pattern = "sent=\"";
				pos = line.indexOf(pattern);
				pos = pos + pattern.length();
				endpos = line.indexOf('"', pos);
				sent_id = Integer.parseInt(line.substring(pos, endpos));
				
				pos = line.indexOf('>', pos);
				endpos = line.indexOf('<', pos);
				token = line.substring(pos, endpos);
				
				KAF_tkn = new KAFToken();
				KAF_tkn.assignToken(token);
				
				if(list.size() < sent_id){
					KAF_sen = new KAFSentence();
					KAF_sen.addToken(KAF_tkn);
					list.add(KAF_sen);
				}
				else{
					KAF_sen.addToken(KAF_tkn);
				}
			}
		}
		
		br.close();
		fr.close();

		return list;
	}
}
