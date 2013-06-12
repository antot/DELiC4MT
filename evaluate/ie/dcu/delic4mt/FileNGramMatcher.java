/*****************************************************************************
 * FileNGramMatcher.java
 *****************************************************************************
 * $Id: FileNGramMatcher.java, v 20111130
 *****************************************************************************
 * Copyright (C) 2011-13,
 * Sudip Kumar Naskar, Dublin City University
 * snaskar at computing dot dcu dot ie
 *
 * some modifications and new methods in 2013 by Antonio Toral, Dublin City University
 * atoral at computing dot dcu dot ie
 *
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
20130605 adding html output for web application
20130514 visualisation of errors
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
	String  lc_s_file, c_file, h_file, src_file, r_file, alignments_file, sentences_file;
	int		no_of_sentences;
	Vector 	sen_n_gram_count;
	Vector 	sen_n_gram_match;
	int		file_n_gram_count;
	int		file_n_gram_match;
	String[] src_checkpoint;
	float[] ch_score_sum;
	float[] ch_score_normalized;
	int[]   noco; //number of occurrences
	int		nouc; // number of unique checkpoint instances
	int[]   rank;
	

	FileNGramMatcher(String src_chkpt_filename, String c_filename, String h_filename, String src_filename, String r_filename, String alignments_filename, String sentences_filename) {
		this.lc_s_file = src_chkpt_filename;
		this.c_file = c_filename;
		this.h_file = h_filename;
		this.src_file = src_filename;
		this.r_file = r_filename;
		this.alignments_file = alignments_filename;
		this.sentences_file = sentences_filename;
		no_of_sentences = 0;
		sen_n_gram_count = new Vector();
		sen_n_gram_match = new Vector();
		file_n_gram_count = 0;
		file_n_gram_match = 0;
		src_checkpoint = new String[20000];
		ch_score_sum = new float[20000];
		ch_score_normalized = new float[20000];
		noco = new int[20000]; 
		nouc = 0; 
		rank = new int[20000];
	}



	void match() throws Exception {
		FileReader fr1 = null, fr2 = null, fr3 = null;
		BufferedReader br1 = null, br2 = null, br3= null;
		String line1, line2, line3, line_src, line_ref, line_alg, line_snt;
		int index;
		
		fr1 = new FileReader(c_file);
		fr2 = new FileReader(h_file);
		fr3 = new FileReader(lc_s_file);

		br1 = new BufferedReader(fr1);
		br2 = new BufferedReader(fr2);
		br3 = new BufferedReader(fr3);
		BufferedReader br_src = new BufferedReader(new FileReader(src_file));
		BufferedReader br_ref = new BufferedReader(new FileReader(r_file));
		BufferedReader br_alg = new BufferedReader(new FileReader(alignments_file));
		BufferedReader br_snt = new BufferedReader(new FileReader(sentences_file));

		line1 = br1.readLine();
		line2 = br2.readLine();
		line3 = br3.readLine();
		line_src = br_src.readLine();
		line_ref = br_ref.readLine();
		line_alg = br_alg.readLine();
		line_snt = br_snt.readLine();


		String htmlout_filename = "data" + System.getProperty("file.separator") + "output.html";
		FileWriter fw_html = new FileWriter(htmlout_filename);
		fw_html.write(
			"<div class=\"output\">\n"
		);

		
		while (line1 != null && line2 != null && line3 != null && line_src != null && line_ref != null && line_alg != null && line_snt != null) {
			SkipNgramMatcher matcher = new SkipNgramMatcher(line1, line2);
			//matcher.computeAllMatches();
			
			line_alg = line_alg.trim();

			String line_src_high = HighlightWordsWithAlignment(line_src, line_alg, 0, 0);
			String line_ref_high = HighlightWordsWithAlignment(line_ref, line_alg, 1, 0);
			String line_src_high_html = HighlightWordsWithAlignment(line_src, line_alg, 0, 1);
			String line_ref_high_html = HighlightWordsWithAlignment(line_ref, line_alg, 1, 1);

			//highlight MT output
			String line_hyp_high = HighlightWordsMatched(line2, line1, 0);
			String line_hyp_high_html = HighlightWordsMatched(line2, line1, 1);

			System.out.println();
			System.out.println("Checkpoint instance\t" + no_of_sentences);
			System.out.println("Sentence\t" + line_snt);
			System.out.println("Checkpoint source\t" + line3);
			System.out.println("Checkpoint target\t" + line1);
			System.out.println("Alignments\t" + line_alg);
			System.out.println("Source\t" + line_src_high);
			System.out.println("Reference\t" + line_ref_high);
			System.out.println("MT output\t" + line_hyp_high);

			matcher.computeAllSkipMatches();	

			System.out.println("Checkpoint ngrams\t" + matcher.total_n_gram_match + "/" + matcher.total_n_gram_count);

			fw_html.write(
				"<div class=\"instance\" id=\"" + no_of_sentences + "\">\n" +
					"<div class=\"checkpoint_instance\"><span class=\"label\">Instance</span><span class=\"entity\">" + no_of_sentences + "</span></div>\n" +
					"<div class=\"sentence\"><span class=\"label\">Sentence</span><span class=\"entity\">" + line_snt + "</span></div>\n" +
					"<div class=\"checkpoint_source\"><span class=\"label\">Checkpoint source</span><span class=\"entity\">"+ line3 + "</span></div>\n" +
					"<div class=\"checkpoint_target\"><span class=\"label\">Checkpoint target</span><span class=\"entity\">" + line1 + "</span></div>\n" +
					"<div class=\"alignment\"><span class=\"label\">Alignment</span><span class=\"entity\">" + line_alg + "</span></div>\n" +
					"<div class=\"source_sentence\"><span class=\"label\">Source sentence</span><span class=\"entity\">" + line_src_high_html + "</span></div>\n" +
					"<div class=\"reference\"><span class=\"label\">Reference</span><span class=\"entity\">" + line_ref_high_html + "</span></div>\n" +
					"<div class=\"MT_output\"><span class=\"label\">MT output</span><span class=\"entity\">" + line_hyp_high_html + "</span></div>\n" +
					"<div class=\"checkpoint_ngrams\"><span class=\"label\">Checkpoint ngrams</span><span class=\"entity\">" + matcher.total_n_gram_match + "/" + matcher.total_n_gram_count + "</span></div>\n" +
				"</div>\n"
			);




			no_of_sentences++;
			sen_n_gram_count.add(new Integer(matcher.total_n_gram_count));
			sen_n_gram_match.add(new Integer(matcher.total_n_gram_match));
			
			index = search(src_checkpoint, line3);
			//System.out.println("src_checkpoint :" + line3);
			if(index == -1)
			{
				//System.out.println("New checkpoint");
				src_checkpoint[nouc] = line3; 
				ch_score_sum[nouc] = (float) matcher.total_n_gram_match / matcher.total_n_gram_count;
				noco[nouc] = 1;
				nouc++;
			}
			else
			{
				//System.out.println("Existing checkpoint");
				float val = ch_score_sum[index]; 
				val = val + ((float) matcher.total_n_gram_match / matcher.total_n_gram_count);
				int prev_noco = noco[index];
				int new_noco = prev_noco + 1;
				noco[index] = new_noco;
				ch_score_sum[index] = val;

			}
			
			String chkpt_stats_filename = "data" + System.getProperty("file.separator") + "linguistic_checkpoint_stats.txt";
			FileWriter fw_lc_stats = new FileWriter(chkpt_stats_filename);
			
			fw_lc_stats.write("checkpoint	occurrences	score_sum	score_normalized\n");
			fw_lc_stats.write("________________________________________________________\n");
			
			float sum, norm_score, value;
			int occurrence;
			
			for(int i=0;i<nouc;i++)
			{
				norm_score = ch_score_sum[i] / noco[i]; 
				ch_score_normalized[i] = norm_score;
			}
			
			for(int i=0;i<nouc;i++)
				fw_lc_stats.write(src_checkpoint[i] + "\t" + noco[i] + "\t" + ch_score_sum[i] + "\t" + ch_score_normalized[i] + "\n");
			
			fw_lc_stats.close();
			
			line1 = br1.readLine();
			line2 = br2.readLine();
			line3 = br3.readLine();
			line_src = br_src.readLine();
			line_ref = br_ref.readLine();
			line_alg = br_alg.readLine();
			line_snt = br_snt.readLine();

		}
		br1.close();
		br2.close();
		fr1.close();
		fr2.close();
		//close also br3 and fr3
		br3.close();
		fr3.close();

		br_src.close();
		br_ref.close();
		br_alg.close();
		br_snt.close();
		





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
			System.out.println("ngrams in checkpoint instance " + i + " = " + sen_n_gram_match.get(i) + "/" + sen_n_gram_count.get(i));
//			System.out.println("ngrams in checkpoint instance " + (i+1) + " = " + sen_n_gram_match.get(i) + "/" + sen_n_gram_count.get(i));
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
		//System.out.println("\nmatching n-grams / n-grams in reference in all sentences in the file = " + file_n_gram_match + " / " + file_n_gram_count);
		System.out.println("Overall ngrams\t" + file_n_gram_match + "/" + file_n_gram_count);
		System.out.println("Overall recall\t" + recall);
		System.out.println("Brevity penalty\t" + brevity_penalty);
		System.out.println("Final score\t" + final_score);


		fw_html.write(
				"<div class=\"foot\">\n" +
					"<div class=\"overall_ngrams\">\n" +
						"<span class=\"label\">Overall ngrams</span>\n" +
						"<span class=\"entity\">" + file_n_gram_match + "/" + file_n_gram_count + "</span>\n" +
					"</div>\n" +
					"<div class=\"overall_recall\">\n" +
						"<span class=\"label\">Overall recall</span>\n" +
						"<span class=\"entity\">" + recall + "</span>\n" +
					"</div>\n" +
					"<div class=\"brevity_penalty\">\n" +
						"<span class=\"label\">Brevity penalty</span>\n" +
						"<span class=\"entity\">" + brevity_penalty + "</span>\n" +
					"</div>\n" +
					"<div class=\"overall_score\">\n" +
						"<span class=\"label\">Overall score</span>\n" +
						"<span class=\"entity\">" + final_score + "</span>\n" +
					"</div>\n" +
				"</div>\n" +
			"</div>\n"
		);
		





		float max, temp_float;
		int max_index, temp_int;
		
		boolean[] b_ranked;
		b_ranked = new boolean[20000];
		for(int i=0; i<nouc;i++)
			b_ranked[i] = false;
		for(int i=0; i<nouc;i++)
		{
			rank[i] = -1;
			max = -1;
			max_index = -1;
			for(int j=0;j<nouc;j++)
			{
				if((b_ranked[j]==false) && (ch_score_normalized[j] > max))
				{
					max = ch_score_normalized[j];
					max_index = j;
				}
			}
	
			if(max_index > -1)
			{
				rank[i] = max_index;
				b_ranked[rank[i]] = true;
			}
		}
		
		String chkpt_stats_filename = "data" + System.getProperty("file.separator") + "linguistic_checkpoint_stats_sorted.txt";
		FileWriter fw_lc_stats = new FileWriter(chkpt_stats_filename);
		
		fw_lc_stats.write("checkpoint	occurrences	score_sum	score_normalized\n");
		fw_lc_stats.write("_____________________________________________________\n");
		
		for(int i=0;i<nouc;i++)
			if(rank[i]>-1) //TODO if added cause getting null pointer
				fw_lc_stats.write(src_checkpoint[rank[i]] + "\t" + noco[rank[i]] + "\t" + ch_score_sum[rank[i]] + "\t" + ch_score_normalized[rank[i]] + "\n");
		
		fw_lc_stats.close();
		
		
//		fw_html.write("<html>\n<head>\n<meta content=\"html; charset=utf-8 http-equiv=Content-Type\">\n");
//		fw_html.write("<title>Statistical Analysis of Linguistic checkpoints</title>\n</head>\n");
//		fw_html.write("<body>\n");
		fw_html.write("<div id=\"tableholder\">\n");
				
		fw_html.write("<table border=\"1\">\n<thead>\n<tr><th>Checkpoint</th><th>Occurrences</th><th>Score_sum</th><th>Score_normalized</th><th>Accuracy</th></tr>\n</thead>\n");
		
		int red, green, blue;
		float x;
		
		fw_html.write("<tbody>\n");
		for(int i=0;i<nouc;i++)
		{
			if(rank[i]>-1)
			{
				fw_html.write("<tr><td>" + src_checkpoint[rank[i]] + "</td>");
				fw_html.write("<td>" + noco[rank[i]] + "</td>");
				fw_html.write("<td>" + ch_score_sum[rank[i]] + "</td>");
				fw_html.write("<td>" + ch_score_normalized[rank[i]] + "</td>");
				
				x = ch_score_normalized[rank[i]];
				green = (int) ((x >= .5)? 255: 510*x);
				red = (int) ((x <= .5)? 255: 255 - 510*(x-.5));
				blue = 0;
				
				String colour_code = hex_colour_code(red, green, blue);
				
				fw_html.write("<td BGCOLOR=\"#" + colour_code + "\"></td>");
				fw_html.write("</tr>\n");
			}
			
		}
		fw_html.write("</tbody>\n");
		fw_html.write("</table>\n");
		fw_html.write("</div>\n");
//		fw_html.write("</body>\n");
//		fw_html.write("</html>\n");
		fw_html.close();
	}
	








	/**
		Highlights words in a sentence that belong to the alignment given

		side, 0 source, 1 target
		format, 0 plain, 1 html

		@author Antonio Toral

		see also HighlightWordsMatched
	*/
	private String HighlightWordsWithAlignment(String sentence, String alignment, int side, int format){

		int alg;


		if(alignment.trim().equals("")) return sentence;

		String[] algs = alignment.split(" ");
		String[] words = sentence.split(" ");


		String add_prefix = "";
		String add_suffix = "";

		if (format == 0){
			add_prefix = "<";
			add_suffix = ">";
		} else {
			add_prefix = "<span class=\"highlight\">";
			add_suffix = "</span>";
		}


		for( int i = 0; i < algs.length; i++){
			String[] alg_sides = algs[i].split("-");
			System.out.println(algs[i] + "\t" + side + "\t" + format);
			if (side == 0)
				alg = Integer.parseInt(alg_sides[0]);
			else
				alg = Integer.parseInt(alg_sides[1]);

			if(!words[alg+1].startsWith(add_prefix))
				words[alg+1] = add_prefix + words[alg+1] + add_suffix;

			
		}

		String output = "";
		for (int i = 0; i< words.length; i++){
			if (i>0) output += " ";
			output += words[i];
		}

		return output;
	}


	/**
		Highlights words in a sentence that match a set of words

		format, 0 plain, 1 html

		@author Antonio Toral

		see also HighlightWordsWithAlignment
	*/
	private String HighlightWordsMatched(String sentence, String words, int format)
	{
		String[] words_sentence = sentence.split(" ");
		String[] words_checkpoint = words.split(" ");

		String add_prefix = "";
		String add_suffix = "";

		if (format == 0){
			add_prefix = "<";
			add_suffix = ">";
		} else {
			add_prefix = "<span class=\"highlight\">";
			add_suffix = "</span>";
		}


		for ( int i = 0; i < words_sentence.length; i++){
			for (int j = 0; j < words_checkpoint.length; j++){
				if ( words_sentence[i].equals(words_checkpoint[j]))
					words_sentence[i] = add_prefix + words_sentence[i] + add_suffix;
			}
		}

		String output = "";
		for (int i = 0; i< words_sentence.length; i++){
			if (i>0) output += " ";
			output += words_sentence[i];
		}

		return output;
	}



	public String convert_int_to_hex_string(int code){
		char[] hex_code = new char[2];
		int ch;
		int index = 1, nod = 0;
		int quotient, remainder;
		while(code > 0){
			quotient = code/16;
			remainder = code - quotient*16;
			if(remainder < 10)
				ch = (int) remainder + '0';
			else
				ch = (int) remainder + 'A' - 10;
			nod++;
			hex_code[index--] = (char)ch;
			code = quotient;
		}
		for(int i=0;i<=index;i++)
			hex_code[i]='0';
		String s_hex_code = new String(hex_code);
		return s_hex_code;
	}
	
	public String hex_colour_code(int r, int g, int b){
		String hex_code = "";
		hex_code = convert_int_to_hex_string(r) + convert_int_to_hex_string(g) + convert_int_to_hex_string(b); 
		
		return hex_code;
	}
	
	public String convert_long_to_hex_string(long code){
		char[] hex_code = new char[6];
		int index = 3;
		int ch;
		int nod = 0;
		long quotient, remainder;
		while(code > 0){
			quotient = code/16;
			remainder = code - quotient*16;
			if(remainder < 10)
				ch = (int) remainder + '0';
			else
				ch = (int) remainder + 'A' - 10;
			nod++;
			hex_code[index--] = (char)ch;
			code = quotient;
		}
		for(int i=0;i<=index;i++)
			hex_code[i]='0';
		hex_code[4] = hex_code[5] = '0';
		String hex_code_string = new String(hex_code); 
		return hex_code_string;
	}
	
	

	public int search(String[] ch_list, String search_key) {
		for (int i = 0; i < nouc; i ++) {
			if(ch_list[i].matches(search_key))
			{
				return i;
			}
		}
		return -1;
	}



	/** removes occurrences of a character from a string */
	public static String removeChar(String s, char c) {
	    String r = "";
	    for (int i = 0; i < s.length(); i ++) {
	       if (s.charAt(i) != c) r += s.charAt(i);
	    }
	    return r;
	}
	


	/** escapes "special" characters in a string */
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
		}
		catch (Exception ex) { ex.printStackTrace(); }
		return tr;
	}
	


	public static void main(String[] args) {
		
		int sen_id = -1;
		Vector token_id;
		FileWriter fw_l_s = null, fw = null, fw_hyp = null, fw_ref = null, fw_src = null, fw_alg = null, fw_snt = null;

		
		try {
			
			boolean wanted_tokenized = false; 
			boolean wanted_lowercased = false;
			boolean b_valid = true;
			int ind = 0;
			

			SentenceExtractor hypReader = null;
			List<Sentence> hyp_list = null;
			String hyp_filename = null;


			//BEGIN treat arguments------------------------------------------
			System.out.println("Number of arguments\t" + args.length);
			
			// The source--target alignment file.
			String alignment_filename = args[1];
			System.out.println("alignment_filename\t" + alignment_filename);
			AlignmentExtractor alignEx = new AlignmentExtractor(alignment_filename);
			List<AlignmentRcd> a_list = alignEx.read();
			
			// The source_KAF file.
			String src_KAF_filename = args[3]; 
			System.out.println("src_KAF_filename\t" + src_KAF_filename);
			KAFReader kr_src = new KAFReader(src_KAF_filename);
			kr_src.parse();
			KAF_Sen k_src_sen = new KAF_Sen();
			
			// The target_KAF file.
			String trgt_KAF_filename = args[5];
			System.out.println("trgt_KAF_filename\t" + trgt_KAF_filename);
			KAFReader kr_trgt = new KAFReader(trgt_KAF_filename);
			kr_trgt.parse();
			KAF_Sen k_trgt_sen = new KAF_Sen();
			
			// The linguistic_checkpoint file 
			TargetReader targetReader = new TargetReader(args[7]);
			List<TargetRcd> t_list = targetReader.read();
			System.out.println("t_list size\t" + t_list.size());
			
			// The MT_output file  
			hyp_filename = args[9];
			//END treat arguments--------------------------------------------






			String src_chkpt_filename = "data" + System.getProperty("file.separator") + "linguistic_checkpoint_src.txt";
			fw_l_s = new FileWriter(src_chkpt_filename);
			
			String chkpt_ref_filename = "data" + System.getProperty("file.separator") + "linguistic_checkpoint_ref.txt";
			fw = new FileWriter(chkpt_ref_filename);
			
			String hypo_filename = "data" + System.getProperty("file.separator") + "hyp.txt";
			fw_hyp = new FileWriter(hypo_filename);
			
			String src_filename = "data" + System.getProperty("file.separator") + "src.txt";
			fw_src = new FileWriter(src_filename);

			String ref_filename = "data" + System.getProperty("file.separator") + "ref.txt";
			fw_ref = new FileWriter(ref_filename);

			//keep track of the sentence each checkpoint instance belongs to
			String sentences_filename = "data" + System.getProperty("file.separator") + "sentences.txt";
			fw_snt = new FileWriter(sentences_filename);

			//keep track of the alignments for each checkpoint
			String alignments_filename = "data" + System.getProperty("file.separator") + "alignments.txt";
			fw_alg = new FileWriter(alignments_filename);


			try {
				hypReader = new SentenceExtractor(hyp_filename); 
			}
			catch (Exception ex) { 
				ex.printStackTrace();
			}
			hyp_list = SentenceExtractor.read();
			

			

			//iterate through checkpoint instances
			for (Iterator<TargetRcd> iter = t_list.iterator(); iter.hasNext(); ) {
				TargetRcd t = iter.next();


				sen_id = t.getEventSentenceId();
				fw_snt.write(sen_id + "\n");
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
					if(i > 0) {
						System.out.print(", ");
						fw_l_s.write(" ");
					}
					token_id_int = ((Integer)token_id.get(i)).intValue();
					k_src_sen = kr_src.getSentence(sen_id-1);
					String src_token = k_src_sen.tokenList.get(token_id_int-1);
					src_token = removeChar(src_token, '\n');
					src_token = removeChar(src_token, ' ');
					System.out.print(src_token);
					fw_l_s.write(src_token);
				}
				fw_l_s.write("\n");
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
							fw_alg.write( a_r.word_alignment.get(j) + " ");
							if( target_equivalent_ids.indexOf( a_r.target_token_id.get(j) ) < 0){
								target_equivalent_ids.add( ((Integer) (a_r.target_token_id.get(j))).intValue() );
//								break;
							}
						}
					}
				}
				System.out.println();
				fw_alg.write("\n");


				
				Collections.sort(target_equivalent_ids);

				System.out.print("Target equivalent ids: ");
				for (int i = 0; i < target_equivalent_ids.size(); i++)
				{
					if(i > 0)
						System.out.print(", ");
					System.out.print(target_equivalent_ids.get(i));
				}
				System.out.println();
				



				k_src_sen = kr_src.getSentence(sen_id-1);
				String src_token, src_sentence="";
				for (int i = 0; i < k_src_sen.tokenList.size(); i++)
				{
					src_token = k_src_sen.tokenList.get(i);
					src_token = removeChar(src_token, '\n');
					src_token = removeChar(src_token, ' ');
					if(src_sentence != null)
						src_sentence += " ";
					src_sentence += src_token;
				}
				System.out.println("Source sentence: " + src_sentence);
				// Add trgt_sen.sentence in 'ref.txt'
				fw_src.write(src_sentence);
				fw_src.write("\n");


				
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
				System.out.println("Target sentence: " + trgt_sentence);
				// Add trgt_sen.sentence in 'ref.txt'
				fw_ref.write(trgt_sentence);
				fw_ref.write("\n");





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
				fw_hyp.write(hyp);
				fw_hyp.write("\n");
			}
			

			fw_l_s.close();
			fw.close(); 
			fw_hyp.close();
			fw_ref.close();
			fw_src.close();
			fw_alg.close();
			fw_snt.close();
			
			FileNGramMatcher matcher = new FileNGramMatcher(src_chkpt_filename, chkpt_ref_filename, hypo_filename, src_filename, ref_filename, alignments_filename, sentences_filename);
			
			matcher.match();
		}
		catch (Exception ex) {
			ex.printStackTrace();
		}
		finally { //TODO check if really needed
			try {
				fw.close(); 
				fw_hyp.close(); 
				fw_ref.close(); 
				fw_src.close();
				fw_alg.close();
				fw_snt.close();

			}
			catch (Exception ex) {
				ex.printStackTrace();
			}
		}
	}
}
