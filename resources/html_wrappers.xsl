<xsl:stylesheet version="1.0"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:param name="html.stylesheet"></xsl:param>

  <!-- content to be included in the header for each page -->
  <xsl:template name="user.head.content">
      <script type='text/javascript' src='http://www.elasticsearch.org/wp-includes/js/jquery/jquery.js?ver=1.8.3'></script>    
      <link rel='stylesheet' 
          id='prettify-gc-syntax-highlighter-css'  
          href='http://www.elasticsearch.org/content/plugins/prettify-gc-syntax-highlighter/prettify.css?ver=3.5.2' 
          type='text/css' 
          media='all' />

      <link rel='stylesheet' 
          id='appStyles-css'  
          href='http://www.elasticsearch.org/content/themes/elasticsearch-org/css/main.css?ver=1376314515' 
          type='text/css' 
          media='all' />

      <script type='text/javascript' src='http://www.elasticsearch.org/content/themes/elasticsearch-org/js/vendor/modernizr-2.6.1.min.js?ver=1'></script>
      <script type='text/javascript' src='http://www.elasticsearch.org/content/themes/elasticsearch-org/js/vendor/selectivizr-min.js?ver=1'></script>
      <script type='text/javascript' src='http://www.elasticsearch.org/content/themes/elasticsearch-org/js/plugins.min.js?ver=1375472072'></script>
      <link rel="stylesheet" type="text/css" href="styles.css" />
  </xsl:template>


  <!-- Wraps the content in required divs -->
  <xsl:template name="local.body.wrapper">
    <xsl:param name="doc" select="self::*"/>
    <xsl:param name="prev"/>
    <xsl:param name="next"/>
    <xsl:param name="nav.context"/>
    <xsl:param name="content" />

    <xsl:apply-templates select="." mode="class.attribute">
      <xsl:with-param name="class" select="'single single-guide'"/>
    </xsl:apply-templates>

      <div class="global_wrapper">
        <div id="index" class="page_content">
          <div class="container">
            <section class="full_width guide">
              <article class="guide_content">
                <!-- include content -->
                <xsl:call-template name="local.body.content">
                  <xsl:with-param name="node" select="$doc"/>
                  <xsl:with-param name="prev" select="$prev" />
                  <xsl:with-param name="next" select="$next" />
                  <xsl:with-param name="nav.context" select="$nav.context" />
                  <xsl:with-param name="content" select="$content" />
                </xsl:call-template>
                <!-- content done -->
              </article>
            </section>
          </div>
        </div>
      </div>
      <script type="text/javascript" src="http://www.elasticsearch.org/content/plugins/prettify-gc-syntax-highlighter/prettify.js?ver=3.5.2"></script>
      <script type="text/javascript" src="http://www.elasticsearch.org/content/plugins/prettify-gc-syntax-highlighter/launch.js?ver=3.5.2"></script>
  </xsl:template>

</xsl:stylesheet>