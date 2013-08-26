<xsl:stylesheet version="1.0"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:import href="asciidoc-8.6.8/docbook-xsl/xhtml.xsl"/> 
  <xsl:import href="website_common.xsl"/> 
  <xsl:import href="html_wrappers.xsl"/> 

  <!-- customise main template to add content wrappers -->
  <xsl:template match="*" mode="process.root">
    <xsl:variable name="doc" select="self::*"/>

    <xsl:call-template name="user.preroot"/>
    <xsl:call-template name="root.messages"/>

    <html>
      <head>
        <xsl:call-template name="system.head.content">
          <xsl:with-param name="node" select="$doc"/>
        </xsl:call-template>
        <xsl:call-template name="head.content">
          <xsl:with-param name="node" select="$doc"/>
        </xsl:call-template>
        <xsl:call-template name="user.head.content">
          <xsl:with-param name="node" select="$doc"/>
        </xsl:call-template>
      </head>
      <body>
        <xsl:call-template name="body.attributes"/>
        <xsl:call-template name="local.body.wrapper" />
      </body>
    </html>
    <xsl:value-of select="$html.append"/>

    <xsl:call-template name="generate.css.files"/>
  </xsl:template>

  <!-- content to wrap -->
  <xsl:template name="local.body.content">
      <xsl:param name="doc" select="self::*"/>
      <xsl:call-template name="user.header.content">
        <xsl:with-param name="node" select="$doc"/>
      </xsl:call-template>
      <xsl:apply-templates select="."/>
      <xsl:call-template name="user.footer.content">
        <xsl:with-param name="node" select="$doc"/>
      </xsl:call-template>
  </xsl:template>


</xsl:stylesheet>

