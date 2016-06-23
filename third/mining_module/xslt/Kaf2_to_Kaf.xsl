<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output indent="yes" method="xml"  />

  <xsl:template match="/">
    <xsl:apply-templates select="KAF2"/>
  </xsl:template>

  <xsl:template match="KAF2">
    <xsl:element name="KAF">
      <xsl:copy-of select="@*"/>
      <xsl:copy-of select="kafHeader"/>
      <text>
	<xsl:copy-of select="//wf"/>
      </text>
      <terms>
	<xsl:apply-templates select="//term"/>
      </terms>
      <deps>
	<xsl:apply-templates select="//dep"/>
      </deps>
      <chunks>
	<xsl:copy-of select="//chunk"/>
      </chunks>
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="sentence | para | idCounters">
    <!-- do nothing -->
  </xsl:template>

  <xsl:template match="term"  >
    <xsl:element name="term">
      <xsl:copy-of select="@*"/>
      <xsl:copy-of select="span"/>
      <xsl:copy-of select="senseAlt"/>
      <xsl:copy-of select="externalReferences"/>
      <xsl:copy-of select="component"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="dep"  >
    <xsl:element name="dep">
      <xsl:copy-of select="@from"/>
      <xsl:copy-of select="@to"/>
      <xsl:copy-of select="@rfunc"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="*">
    <xsl:copy-of select="."/>
  </xsl:template>

  
</xsl:stylesheet>