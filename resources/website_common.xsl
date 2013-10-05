<xsl:stylesheet version="1.0"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <!-- css -->
  <xsl:param name="generate.id.attributes"  select="1"/>
  <xsl:param name="css.decoration"          select="0"/>
  <xsl:param name="html.stylesheet"></xsl:param>

  <!-- nav -->
  <xsl:param name="part.autolabel"          select="0"/>
  <xsl:param name="chapter.autolabel"       select="0"/>
  <xsl:param name="section.autolabel"       select="0"/>

  <!-- layout -->
  <xsl:param name="table.borders.with.css"  select="0"/>
  <xsl:param name="highlight.source"        select="1"/>

  <xsl:param name="generate.toc"></xsl:param>


  <!-- remove part/chapter/section titles -->
  <xsl:param name="local.l10n.xml" select="document('')"/>
  <l:i18n xmlns:l="http://docbook.sourceforge.net/xmlns/l10n/1.0">
    <l:l10n language="en">
      <l:context name="title">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="title-unnumbered">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="title-numbered">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="xref">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="xref-number">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="xref-number-and-title">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
    </l:l10n>
  </l:i18n>

  <!-- add prettyprint classes to code blocks -->
  <xsl:template match="programlisting" mode="common.html.attributes">
    <xsl:param name="class">
      <xsl:value-of select="local-name(.)" />
      <xsl:if test="@language != ''"> prettyprint lang-<xsl:value-of select="@language" /></xsl:if>
    </xsl:param>
    <xsl:param name="inherit" select="0"/>
    <xsl:call-template name="generate.html.lang"/>
    <xsl:call-template name="dir">
      <xsl:with-param name="inherit" select="$inherit"/>
    </xsl:call-template>
    <xsl:apply-templates select="." mode="class.attribute">
      <xsl:with-param name="class" select="$class"/>
    </xsl:apply-templates>
    <xsl:call-template name="generate.html.title"/>
  </xsl:template>

  <!-- added and deprecated markup -->
  <xsl:template match="phrase[@revisionflag='added']">
    <span class="added">
      [<span class="version"><xsl:value-of select="attribute::revision" /></span>]
      <span class="detail">
        <xsl:apply-templates />
      </span>
    </span>
  </xsl:template>

  <xsl:template match="phrase[@revisionflag='deleted']">
    <span class="deprecated">
      [<span class="version"><xsl:value-of select="attribute::revision" /></span>]
      <span class="detail">
        <xsl:apply-templates />
      </span>
    </span>
  </xsl:template>

</xsl:stylesheet>

