/*****************************************************************************
 * SkipNGramMatcher.java
 *****************************************************************************
 * $Id: SkipNGramMatcher.java, v 20110724
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

/*
CHANGELOG
20130605 adapting output for web application
*/

package ie.dcu.delic4mt;
import java.util.regex.*;
import java.util.*;
import java.io.*;

class SkipNgramMatcher
{
	int     maxGrams;
	Vector  ngramListA;
	Vector	ngramListB;
	Vector	ngramMatchList;
	Vector	wordsA, wordsB;
	Vector 	n_gram_count;
	Vector 	n_gram_match;
	int total_n_gram_count;
	int total_n_gram_match; 

	SkipNgramMatcher(String a, String b) {
		String word;
		ngramListA = new Vector();;
		ngramListB = new Vector();;
		ngramMatchList = new Vector();
		wordsA = new Vector();
		wordsB = new Vector();
		n_gram_count = new Vector();
		n_gram_match = new Vector();
		total_n_gram_count = 0;
		total_n_gram_match = 0;

		// Get the number of words for A and B
		StringTokenizer st = new StringTokenizer(a, " \r\n");
		while (st.hasMoreTokens()) {
			word = st.nextToken();
			//System.out.println("a_word: " + word);
			wordsA.add(word);
		}

		st = new StringTokenizer(b, " \r\n");
		while (st.hasMoreTokens()) {
			word = st.nextToken();
			//System.out.println("b_word: " + word);
			wordsB.add(word);
		}

		maxGrams = Math.min(wordsA.size(), wordsB.size());
	}

	void computeAllSkipMatches()
	{
		for (int i = 1; i <= maxGrams; i++) {
			computeSkipMatches(i);
			total_n_gram_count += ((Integer) n_gram_count.get(i-1)).intValue();
		}
		
		for (int i = 0; i < maxGrams; i++)
			total_n_gram_match += ((Integer) n_gram_match.get(i)).intValue();
		
		System.out.print("ngram matches\t");
		for (int i = 0; i < total_n_gram_match; i++){
			System.out.print(ngramMatchList.elementAt(i));
			if (i+1 < total_n_gram_match) System.out.print(", ");
		}
			
		System.out.println("");
//		System.out.println("Total n_gram matches: " + total_n_gram_match);
//		System.out.println("Total n_gram count in reference: " + total_n_gram_count);
		//System.out.println("Checkpoint ngrams\t" + total_n_gram_match + "/" + total_n_gram_count);
	}
	
	void computeSkipMatches(int n)
	{
		int i = 0, j = 0, k = 0, size = 0;
		StringBuffer ngram;
		int count = 0;
		boolean b_valid;

		//count_n_gram_match.add(new Integer(0));
		
		for (i = 0; i < wordsA.size()-n+1; i++)
		{
			if(wordsA.elementAt(i).equals("*") == false)
			{
				b_valid = true;
				ngram = new StringBuffer();
				ngram.append(wordsA.elementAt(i));
				for (j = 1; j < n; j++)
				{
					if(wordsA.elementAt(i+j).equals("*") == true)
						ngram.append(".*.");
					else
					{
						if( ( (ngram.length() > 3) && (ngram.charAt(ngram.length()-3) == '.') && (ngram.charAt(ngram.length()-2) == '*') && (ngram.charAt(ngram.length()-1) == '.')) == false)
							ngram.append(" ");
						ngram.append(wordsA.elementAt(i+j));
					}
				}
				
				if(wordsA.elementAt(i+n-1).equals("*") == true)
					b_valid = false;
				
				if(b_valid == true)
				{
					ngramListA.add(new String(ngram.toString()));
//					System.out.println("Got new " + n + "-gram: " + ngramListA.elementAt(total_n_gram_count + count));
					count++;
				}
			}
		}
		
		n_gram_count.add(new Integer(count));
//		System.out.println("Number of " + n + "-grams in reference: " + n_gram_count.get(n-1));
		
		count = 0;
		size = ngramListA.size();
		for (i = 0; i < wordsB.size()-n+1; i++)
		{
			ngram = new StringBuffer();
			ngram.append(wordsB.elementAt(i));
			for (j = 1; j < n; j++) {
				ngram.append(" ");
				ngram.append(wordsB.elementAt(i+j));
			}
			//System.out.println("Searching " + n + "-gram: " + ngram.toString());
			
			for (k = 0; k < size; k++)
			{
				Pattern p = Pattern.compile((ngramListA.elementAt(k)).toString());
				Matcher m = p.matcher(ngram.toString());
				if(m.matches())
				{
					if( ngramMatchList.indexOf( ngramListA.elementAt(k) ) < 0){
						ngramMatchList.add(new String((ngramListA.elementAt(k)).toString()));
//						System.out.println("Matched " + n + "-gram: " + ngramListA.elementAt(k).toString());
						count++;
						break;
					}
				}
			}
		}
		n_gram_match.add(new Integer(count));
//		System.out.println("# of matching " + n + "-grams = " + n_gram_match.get(n-1));
	}
}


