/*****************************************************************************
 * XMLTargetReader.java
 *****************************************************************************
 * $Id: XMLTargetReader.java, v 20110724
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

class XMLTargetReader extends DefaultHandler {

	StringBuffer buff;
	String currentTagOpened;
	Vector<String> sentences;
	XMLReader    xmlReader;
	String       fileName;

	XMLTargetReader(String fileName) throws Exception {
		this.fileName = fileName;
		buff = new StringBuffer();
		sentences = new Vector<String>();
		xmlReader = XMLReaderFactory.createXMLReader();
		xmlReader.setContentHandler(this);
		xmlReader.setErrorHandler(this);
	}

	public void parse() throws Exception {
		xmlReader.parse(new InputSource(new FileReader(fileName)));
	}

	public void startElement(String uri, String localName, String qName, Attributes attributes) throws SAXException {
		currentTagOpened = qName;
	}

	 public void endElement(String uri, String name, String qName) throws SAXException {
		if ( currentTagOpened.equals("seg")) {
			sentences.add(buff.toString());
			buff = new StringBuffer();
		}
	 }

	 public void characters(char ch[], int start, int length) throws SAXException {
		if ( currentTagOpened.equals("seg")) {
			buff.append(new String(ch, start, length));
		}
	 }

	 public String toString() {
			StringBuffer buff = new StringBuffer();
			for (Iterator iter = sentences.iterator(); iter.hasNext(); ) {
				buff.append(iter.next());
				buff.append("\n");
			}
			return buff.toString();
	 }

	 public String getTargetSentence(int i) {
		return sentences.elementAt(i);
	 }

	 public static String removeChar(String s, char c) {
		 String r = "";
		 for (int i = 0; i < s.length(); i ++) {
			 if (s.charAt(i) != c) r += s.charAt(i);
		 }
		 return r;
	 }

	 public static void main(String[] args) {
		try {
			/*XMLTargetReader tr = new XMLTargetReader(args[0]);
			tr.parse();
			System.out.println(tr);
			FileWriter fw = null;
			//fw = new FileWriter("data\\hyp_google.txt");
			fw = new FileWriter(args[1]);
			String hyp = null;
			for(int i=0;i<tr.sentences.size();i++){
				hyp = tr.sentences.get(i);
				hyp = removeChar(hyp, '\n');
				fw.write(hyp);
				fw.write("\n");
			}
			fw.close();*/
			
			XMLTargetReader tr = new XMLTargetReader(args[0]);
			tr.parse();
			System.out.println(tr);
			
			
			/*FileWriter fw = null;
			//fw = new FileWriter("data\\hyp_google.txt");
			fw = new FileWriter(args[1]);
			String hyp = null;
			for(int i=0;i<tr.sentences.size();i++){
				hyp = tr.sentences.get(i);
				hyp = removeChar(hyp, '\n');
				fw.write(hyp);
				fw.write("\n");
			}
			fw.close();*/
			
			File fileName = new File(args[1]);
			Writer out = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(fileName), "UTF8"));
	 
			String hyp = null;
			for(int i=0;i<tr.sentences.size();i++){
				hyp = tr.sentences.get(i);
				hyp = removeChar(hyp, '\n');
				hyp = removeChar(hyp, '\r');
				out.append(hyp).append("\n");
			}
			out.flush();
			out.close();
		}
		catch (Exception ex) { ex.printStackTrace(); }
	}
}


