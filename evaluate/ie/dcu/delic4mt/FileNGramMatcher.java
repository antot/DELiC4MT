/*****************************************************************************
 * FileNGramMatcher.java
 *****************************************************************************
 * $Id: FileNGramMatcher.java, v 20111130
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
20111130 change of input parameters
*/

package ie.dcu.delic4mt;
import java.util.regex.*;
import java.util.*;
import java.io.*;
import java.util.Vector;
import java.io.BufferedReader;
import java.io.FileReader;
import java.util.Vector;
import java.io.BufferedReader;
import java.io.FileReader;
import java.util.Vector;

public class FileNGramMatcher {
	String c_file, h_file, r_file;
	int		no_of_sentences;
	Vector 	sen_n_gram_count;
	Vector 	sen_n_gram_match;
	int		file_n_gram_count;
	int		file_n_gram_match;
	
	// (chkpt_ref_filename, hypo_filename, ref_filename)
	FileNGramMatcher(String c_filename, String h_filename, String r_filename) {
		this.c_file = c_filename;
		this.h_file = h_filename;
		this.r_file = r_filename;
		no_of_sentences = 0;
		sen_n_gram_count = new Vector();
		sen_n_gram_match = new Vector();
		file_n_gram_count = 0;
		file_n_gram_match = 0;
	}

	void match() throws Exception {
		FileReader fr1 = null, fr2 = null;
		BufferedReader br1 = null, br2 = null;
		String line1, line2;
		
		fr1 = new FileReader(c_file);
		fr2 = new FileReader(h_file);
		br1 = new BufferedReader(fr1);
		br2 = new BufferedReader(fr2);

		line1 = br1.readLine();
		line2 = br2.readLine();

		while (line1 != null && line2 != null) {
			SkipNgramMatcher matcher = new SkipNgramMatcher(line1, line2);
			//matcher.computeAllMatches();
			System.out.println();
			System.out.println("Checking for n-gram matches for checkpoint instance: " + no_of_sentences);
			System.out.println("Ref: " + line1);
			System.out.println("Hypo: " + line2);
			
			matcher.computeAllSkipMatches();
			no_of_sentences++;
			sen_n_gram_count.add(new Integer(matcher.total_n_gram_count));
			sen_n_gram_match.add(new Integer(matcher.total_n_gram_match));
			
			line1 = br1.readLine();
			line2 = br2.readLine();
		}
		br1.close();
		br2.close();
		fr1.close();
		fr2.close();
		
		int hyp_length, ref_length;
		Vector 	hyp_len;
		Vector 	ref_len;
		long	sum_hyp_len = 0;
		long	sum_ref_len = 0;
		
		fr1 = new FileReader(h_file);
		fr2 = new FileReader(r_file);
		br1 = new BufferedReader(fr1);
		br2 = new BufferedReader(fr2);
		hyp_len = new Vector();
		ref_len = new Vector();
		
		line1 = br1.readLine();
		line2 = br2.readLine();
		
		while (line1 != null && line2 != null) {
			
			StringTokenizer hyp = new StringTokenizer(line1);
			hyp_length = 0;
			while(hyp.hasMoreTokens())
			{
				hyp_length++;
				String word = hyp.nextToken();
			}
			hyp_len.add(new Integer(hyp_length));
			
			StringTokenizer ref = new StringTokenizer(line2);
			ref_length = 0;
			while(ref.hasMoreTokens())
			{
				ref_length++;
				String word = ref.nextToken();
			}
			ref_len.add(new Integer(ref_length));
			
			sum_hyp_len += (long)hyp_length;
			sum_ref_len += (long)ref_length;
			
			line1 = br1.readLine();
			line2 = br2.readLine();
		}
		br1.close();
		br2.close();
		fr1.close();
		fr2.close();
		
		System.out.println();
		for(int i=0;i<no_of_sentences;i++)
		{
			System.out.println("matching n-grams / n-grams in reference in sentence " + (i+1) + " = " + sen_n_gram_match.get(i) + " / " + sen_n_gram_count.get(i));
			//System.out.println("Number of n-grams in reference sentence " + i+1 + " = " + sen_n_gram_count.get(i));
			file_n_gram_match += ((Integer) sen_n_gram_match.get(i)).intValue();
			file_n_gram_count += ((Integer) sen_n_gram_count.get(i)).intValue();
		}
			
		float brevity_penalty = (float) sum_ref_len / sum_hyp_len;
		//float brevity_penalty = 1;
		if(brevity_penalty > 1.0)
			brevity_penalty = (float)1.0;
		float recall = (float) file_n_gram_match / file_n_gram_count;
		float final_score = (float) recall * brevity_penalty;
		System.out.println();
		System.out.println("\nmatching n-grams / n-grams in reference in all sentences in the file = " + file_n_gram_match + " / " + file_n_gram_count);
		System.out.println("Recall for this checkpoint: " + recall);
		System.out.println("Brevity penalty: " + brevity_penalty);
		System.out.println("Final score: " + final_score);
		
	}

	public static String removeChar(String s, char c) {
	    String r = "";
	    for (int i = 0; i < s.length(); i ++) {
	       if (s.charAt(i) != c) r += s.charAt(i);
	    }
	    return r;
	}
	
	public static String replaceParentheses(String s1) {
	    String r = "";
	    char c = 0;
	    for (int i = 0; i < s1.length(); i ++) {
	       c = s1.charAt(i);
	       if ( (s1.charAt(i) == ')') || (s1.charAt(i) == '(') || (s1.charAt(i) == '[') || (s1.charAt(i) == ']') || (s1.charAt(i) == '{') || (s1.charAt(i) == '}') || (s1.charAt(i) == '\\') || (s1.charAt(i) == '^')  || (s1.charAt(i) == '-') || (s1.charAt(i) == '$')  || (s1.charAt(i) == '?')  || (s1.charAt(i) == '*')  || (s1.charAt(i) == '+') ) 
	    	   r += '\\';
	       r += s1.charAt(i);
	    }
	    return r;
	}
	
	private static XMLTargetReader loadTargetsFromXML(String fileName) {
		XMLTargetReader tr = null;
		try {
			tr = new XMLTargetReader(fileName);
			tr.parse();
			//System.out.println(tr);
		}
		catch (Exception ex) { ex.printStackTrace(); }
		return tr;
	}
	
	public static void main(String[] args) {
		
		int sen_id = -1;
		Vector token_id;
		FileWriter fw = null, fw2 = null, fw3 = null;
		String language[] = {"en", "de", "it", "nl"};
		
		try {
			
			boolean wanted_tokenized = false; 
			boolean wanted_lowercased = false;
			boolean b_valid = true;
			int ind = 0;
			
			System.out.println("Number of arguments: " + args.length);
			
			String chkpt_ref_filename = "data" + System.getProperty("file.separator") + "linguistic_checkpoint_ref.txt";
			System.out.println("chkpt_ref_filename: " + chkpt_ref_filename);
			fw = new FileWriter(chkpt_ref_filename);
			
			String hypo_filename = "data" + System.getProperty("file.separator") + "hyp.txt";
			System.out.println("hypo_filename: " + hypo_filename);
			fw2 = new FileWriter(hypo_filename);
			
			String ref_filename = "data" + System.getProperty("file.separator") + "ref.txt";
			System.out.println("ref_filename: " + ref_filename);
			fw3 = new FileWriter(ref_filename);

			// The source--target alignment file.
			String alignment_filename = args[1]; 
			System.out.println("alignment_filename: " + alignment_filename);
			AlignmentExtractor alignEx = new AlignmentExtractor(alignment_filename);
			List<AlignmentRcd> a_list = alignEx.read();
			
			// The source_KAF file.
			String src_KAF_filename = args[3]; 
			System.out.println("src_KAF_filename: " + src_KAF_filename);
			KAFReader kr_src = new KAFReader(src_KAF_filename);
			kr_src.parse();
			KAF_Sen k_src_sen = new KAF_Sen();
			
			// The target_KAF file.
			String trgt_KAF_filename = args[5];
			System.out.println("trgt_KAF_filename: " + trgt_KAF_filename);
			KAFReader kr_trgt = new KAFReader(trgt_KAF_filename);
			kr_trgt.parse();
			KAF_Sen k_trgt_sen = new KAF_Sen();
			
			// The linguistic_checkpoint file 
			TargetReader targetReader = new TargetReader(args[7]);
			List<TargetRcd> t_list = targetReader.read();
			System.out.print("t_list size: " + t_list.size());
			//System.exit(1);
			
			SentenceExtractor hypReader = null;
			List<Sentence> hyp_list = null;
			String hyp_filename = null;
			
			// The MT_output file  
			hyp_filename = args[9];
			
			try {
				hypReader = new SentenceExtractor(hyp_filename); 
			}
			catch (Exception ex) { 
				ex.printStackTrace();
			}
			hyp_list = SentenceExtractor.read();
			
			/*String reference_filename = "data" + System.getProperty("file.separator") + language[src_language_index] + "-" + language[trgt_language_index] + "." + language[trgt_language_index] + ".test.tokenized";
			SentenceExtractor senReader = new SentenceExtractor(reference_filename);
			List<Sentence> s_list = SentenceExtractor.read();*/
			
			for (Iterator<TargetRcd> iter = t_list.iterator(); iter.hasNext(); ) {
				TargetRcd t = iter.next();
				sen_id = t.getEventSentenceId();
				System.out.println();
				System.out.print("Sen_id: " + sen_id + "\ttoken_id: ");
				int ii = -1;
				token_id = new Vector();
				token_id.add(t.getEventTokenId());
				for (int i = 0; i < t.getNumRoles(); i++) {
					token_id.add(t.getRoleTokenId(i));
				}
				for (int i = 0; i < token_id.size(); i++)
				{
					if(i > 0)
						System.out.print(", ");
					System.out.print(token_id.get(i));
				}
				System.out.println();
				
				System.out.print("Source tokens: \t");
				int token_id_int = -1;
				for (int i = 0; i < token_id.size(); i++)
				{
					if(i > 0)
						System.out.print(", ");
					token_id_int = ((Integer)token_id.get(i)).intValue();
					k_src_sen = kr_src.getSentence(sen_id-1);
					String src_token = k_src_sen.tokenList.get(token_id_int-1);
					src_token = removeChar(src_token, '\n');
					src_token = removeChar(src_token, ' ');
					System.out.print(src_token);
				}
				System.out.println();
				
				AlignmentRcd a_r = new AlignmentRcd();
				a_r = a_list.get(sen_id-1);
				int key = 0, src_token_ind = -1;
				Vector target_equivalent_ids;
				target_equivalent_ids = new Vector();
				System.out.print("Alignments: \t");
				for (int i = 0; i < token_id.size(); i++)
				{
					key = ((Integer) token_id.get(i)).intValue() - 1;
					for(int j=0; j<a_r.word_alignment.size() ; j++){
						src_token_ind = ((Integer) (a_r.source_token_id.get(j))).intValue();
						if(key == src_token_ind ){
							System.out.print( a_r.word_alignment.get(j) + ", ");
							if( target_equivalent_ids.indexOf( a_r.target_token_id.get(j) ) < 0){
								target_equivalent_ids.add( ((Integer) (a_r.target_token_id.get(j))).intValue() );
//								break;
							}
						}
					}
				}
				System.out.println();
				
				Collections.sort(target_equivalent_ids);

				System.out.print("Target equivalent ids: ");
				for (int i = 0; i < target_equivalent_ids.size(); i++)
				{
					if(i > 0)
						System.out.print(", ");
					System.out.print(target_equivalent_ids.get(i));
				}
				System.out.println();
				
				/*Sentence trgt_sen = new Sentence();
				trgt_sen = s_list.get(sen_id-1);
				System.out.println("Target sentence: " + trgt_sen.sentence);
				// Add trgt_sen.sentence in 'ref.txt'
				fw3.write(trgt_sen.sentence);*/
				
				k_trgt_sen = kr_trgt.getSentence(sen_id-1);
				String trgt_token, trgt_sentence="";
				for (int i = 0; i < k_trgt_sen.tokenList.size(); i++)
				{
					trgt_token = k_trgt_sen.tokenList.get(i);
					trgt_token = removeChar(trgt_token, '\n');
					trgt_token = removeChar(trgt_token, ' ');
					if(trgt_sentence != null)
						trgt_sentence += " ";
					trgt_sentence += trgt_token;
				}
				//System.out.println("Target sentence: " + k_trgt_sen.toString());
				System.out.println("Target sentence: " + trgt_sentence);
				// Add trgt_sen.sentence in 'ref.txt'
				//fw3.write(k_trgt_sen.toString());
				fw3.write(trgt_sentence);
				
				fw3.write("\n");
				System.out.print("Target equivalent tokens: \t");
				
				int prev_token_id = -1, current_token_id = -1;
				for (int i = 0; i < target_equivalent_ids.size(); i++)
				{
					if (i > 0) {
						System.out.print(" ");
						fw.write(" ");
					}
//					token_id_int = ((Integer)token_id.get(i)).intValue();
					
					k_trgt_sen = kr_trgt.getSentence(sen_id-1);
					current_token_id = ((Integer) (target_equivalent_ids.get(i))).intValue();
					trgt_token = k_trgt_sen.tokenList.get(current_token_id);
					trgt_token = removeChar(trgt_token, '\n');
					trgt_token = removeChar(trgt_token, ' ');
					System.out.print(trgt_token);
					
					if( (i>0) && (current_token_id - prev_token_id > 1) )
						fw.write( "* " );
					trgt_token = replaceParentheses(trgt_token);
					fw.write( trgt_token );
					prev_token_id = current_token_id;
				}
				fw.write("\n");
				System.out.println();
				
				// Add the system generated hypothesis for this checkpoint instance to 'hyp.txt'
				
				String hyp = hyp_list.get(sen_id-1).sentence;
				
				hyp = removeChar(hyp, '\n');
				fw2.write(hyp);
				fw2.write("\n");
			}
			
			fw.close(); 
			fw2.close();
			fw3.close();
			
			FileNGramMatcher matcher = new FileNGramMatcher(chkpt_ref_filename, hypo_filename, ref_filename);
			
			matcher.match();
		}
		catch (Exception ex) {
			ex.printStackTrace();
		}
		finally {
			try {
				fw.close(); 
				fw2.close(); 
				fw3.close(); 
			}
			catch (Exception ex) { }
		}
	}
}
