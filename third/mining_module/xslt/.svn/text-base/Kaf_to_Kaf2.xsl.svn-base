<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:param name="filename">2728.met</xsl:param>
  <xsl:param name="pathname">D:/Linee Guida/SemanticWeb/Kyoto/Data/stylesheet/source/</xsl:param>
  <xsl:variable name="name" select="concat($pathname,$filename)"></xsl:variable>
  <xsl:variable name="meta" select="document($name)" />
  <xsl:output indent="yes" method="xml" />

  <xsl:template match="/">
    <xsl:apply-templates select="/KAF2"/>
  </xsl:template>
  
  <xsl:template match="KAF2">
    <xsl:copy>
      <xsl:apply-templates select="@*" />

      <!--
	  <meta>
	  <title><xsl:value-of select="$meta//ADMIN_TITLE"/></title>
	  <originalfilename><xsl:value-of select="$meta//ADMIN_DOC_FILE_NAME"/></originalfilename>
	  <filename><xsl:value-of select="$filename"/></filename>
	  <pages><xsl:value-of select="$meta//ADMIN_DOC_NR_PAGES"/></pages>
	  <filetype><xsl:value-of select="$meta//ADMIN_FILE_SOURCE_TYPE"/></filetype>
	  </meta>
      -->
      <xsl:copy-of select="kafHeader"/>
     
      <xsl:apply-templates select="//sentence"/>
     
      <xsl:copy-of select="//idCounters"/>

      <xsl:element name="facts">
        <xsl:copy-of select="//fact"/>
      </xsl:element>
    </xsl:copy>
  </xsl:template>

  
  <!--  -->
  <xsl:template match="sentence">
    <!-- <para num="1"> -->
    <xsl:copy>
      <xsl:apply-templates select="@*" />
      <xsl:copy-of select="text"/>
      <xsl:apply-templates select="terms"/>
      <xsl:copy-of select="chunks"/>
    </xsl:copy>
    <!-- </para> -->
  </xsl:template>

  <xsl:template match="terms"> 
    <xsl:copy>
      <xsl:apply-templates select="term"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="term">
    <xsl:copy>
      <xsl:apply-templates select="@*" />
      <xsl:copy-of select="*"/>

     <!-- move <dep> into <term> -->
     <xsl:variable name="tid" select="string(@tid)" />
     <xsl:apply-templates select="../../deps/dep[@from=$tid]"/>

    </xsl:copy>
  </xsl:template>

  <xsl:template match="dep">
    <xsl:copy>
      <xsl:apply-templates select="@*" />
      <xsl:attribute name="source">
	<xsl:value-of select="../../term[@tid=current()/@from][1]/@lemma" />
      </xsl:attribute>
      <xsl:attribute name="target">
	<xsl:value-of select="../../term[@tid=current()/@to][1]/@lemma" />
      </xsl:attribute>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*">
    <xsl:copy-of select="."/>
  </xsl:template>

  <!-- <xsl:template match="chunk"> -->
  <!--   <xsl:copy> -->
  <!--     <xsl:apply-templates select="@*" /> -->
  <!--     <xsl:for-each select="span/target"> -->
  <!-- 	<term id="{@id}" lemma="{//term[@tid=current()/@id][1]/@lemma}" /> -->
  <!--     </xsl:for-each> -->
  <!--   </xsl:copy> -->
  <!-- </xsl:template> -->

  <!-- <xsl:template match="@tid" priority="3"> -->
  <!--   <xsl:copy-of select="."/> -->
  <!--   <xsl:apply-templates select="//dep[@from=.]" /> -->
  <!-- </xsl:template> -->

</xsl:stylesheet>
