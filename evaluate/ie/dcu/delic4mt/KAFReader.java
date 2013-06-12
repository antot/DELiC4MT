/*****************************************************************************
 * KAFReader.java
 *****************************************************************************
 * $Id: KAFReader.java, v 20110724
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
import org.xml.sax.*;
import org.xml.sax.helpers.*;


class KAF_Sen {
	int sentenceId;
	String temp_token;
	String sentence;
	List<String> tokenList;
	
	KAF_Sen() {
		sentence = "";
		tokenList = new Vector<String>(100);
	}
	
	KAF_Sen(int sentenceId) {
		this.sentenceId = sentenceId;
		//sentence = null;
		tokenList = new Vector<String>(100);
	}
		
	String removeChar(String s, char c) {
	    String r = "";
	    for (int i = 0; i < s.length(); i ++) {
	       if (s.charAt(i) != c) r += s.charAt(i);
	    }
	    return r;
	}
	
	void addToken(String token) {
		/*temp_token = token;
		temp_token = removeChar(temp_token, '\n');
		temp_token = removeChar(temp_token, ' ');
		tokenList.add(temp_token);
		if(sentence != null)
			sentence += " ";
		sentence = sentence + temp_token;*/
		tokenList.add(token);
		
	}
	
	public String toString() {
		return sentenceId + ":" + tokenList.toString();
	}
}

class KAFReader extends DefaultHandler {

	StringBuffer buff;
	String currentTagOpened;
	XMLReader    xmlReader;
	String       fileName;
	Vector<KAF_Sen>  kafList;
	KAF_Sen          kaf;
	int          currentSenId;

	KAFReader(String fileName) throws Exception {
		this.fileName = fileName;
		kafList = new Vector<KAF_Sen>();
		buff = new StringBuffer();
		xmlReader = XMLReaderFactory.createXMLReader();
		xmlReader.setContentHandler(this);
		xmlReader.setErrorHandler(this);
		kaf = null;
		currentSenId = -1;
	}

	public void parse() throws Exception {
		xmlReader.parse(new InputSource(new FileReader(fileName)));
		kafList.add(kaf);
		//System.out.println(kaf);
	}

	/*public void endDocument() throws SAXException
	{
		kafList.add(kaf);
	}*/
	
	public void startElement(String uri, String localName, String qName, Attributes attributes) throws SAXException {
		currentTagOpened = qName;
		int thisSentenceId = -1;
		if ( currentTagOpened.equals("wf")) {
			for (int i = 0; i < attributes.getLength(); i++) {
				String attrName = attributes.getQName(i);
				String attrVal = attributes.getValue(i);
				if (attrName.equals("sent")) {
					thisSentenceId = Integer.parseInt(attrVal);
					if (currentSenId < 0 || thisSentenceId != currentSenId) {
						if (kaf!=null)
							kafList.add(kaf);
						kaf = new KAF_Sen(thisSentenceId);
						currentSenId = thisSentenceId;
					}
				}
			}
		}
	}

	 public void endElement(String uri, String name, String qName) throws SAXException {
		if ( currentTagOpened.equals("wf")) {
			kaf.addToken(buff.toString());
			buff = new StringBuffer();
		}
	 }

	 public void characters(char ch[], int start, int length) throws SAXException {
		if ( currentTagOpened.equals("wf")) {
			buff.append(new String(ch, start, length));
		}
	 }

	 public String toString() {
			StringBuffer buff = new StringBuffer();
			for (Iterator iter = kafList.iterator(); iter.hasNext(); ) {
				buff.append(iter.next());
				buff.append("\n");
			}
			return buff.toString();
	 }

	 public KAF_Sen getSentence(int i) {
		return kafList.elementAt(i);
	 }

	 public static void main(String[] args) {
		/*try {
			KAFReader tr = new KAFReader(args[0]);
			tr.parse();
			System.out.println(tr);
		}
		catch (Exception ex) { ex.printStackTrace(); }*/
	 }
}


