<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.1"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:premis="http://www.loc.gov/premis/v3"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	
<xsl:output method="xml" indent="yes"/>
	
<xsl:template match="/">
	<premis:premis xmlns="http://www.loc.gov/premis/v3"
		xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
		xsi:schemaLocation="http://www.loc.gov/premis/v3 https://www.loc.gov/standards/premis/premis.xsd" 
		version="3.0">
		<xsl:apply-templates select="data/file" />
		<xsl:apply-templates select="data/agent" />
		<xsl:apply-templates select="data/event" />
	</premis:premis>
</xsl:template>

<xsl:template match="file">
	<premis:object xsi:type="premis:file">
		<premis:objectIdentifier>
			<premis:objectIdentifierType>local</premis:objectIdentifierType>
			<premis:objectIdentifierValue><xsl:apply-templates select="objectid" /></premis:objectIdentifierValue>
		</premis:objectIdentifier>
		<premis:objectCharacteristics>
			<premis:fixity>
				<premis:messageDigestAlgorithm>SHA-256</premis:messageDigestAlgorithm>
				<premis:messageDigest><xsl:apply-templates select="fixity" /></premis:messageDigest>
			</premis:fixity>
			<premis:size><xsl:apply-templates select="size" /></premis:size>
			<premis:format>
				<premis:formatDesignation>
					<premis:formatName><xsl:apply-templates select="format" /></premis:formatName>
				</premis:formatDesignation>
			</premis:format>
		</premis:objectCharacteristics>
		<xsl:choose>
		<xsl:when test="string(label)">
		<premis:originalName><xsl:apply-templates select="label" /></premis:originalName>
		</xsl:when>
		</xsl:choose>
		<xsl:choose>
		<xsl:when test="string(linkedobjecttype)">
		<premis:relationship>
			<premis:relationshipType><xsl:apply-templates select="reltype" /></premis:relationshipType>
			<premis:relationshipSubType><xsl:apply-templates select="relsubtype" /></premis:relationshipSubType>
			<premis:relatedObjectIdentifier>
				<premis:relatedObjectIdentifierType><xsl:apply-templates select="linkedobjecttype" /></premis:relatedObjectIdentifierType>
				<premis:relatedObjectIdentifierValue><xsl:apply-templates select="linkedobjectvalue" /></premis:relatedObjectIdentifierValue>
			</premis:relatedObjectIdentifier>
			<premis:relatedEventIdentifier>
				<premis:relatedEventIdentifierType><xsl:apply-templates select="linkedeventtype" /></premis:relatedEventIdentifierType>
				<premis:relatedEventIdentifierValue><xsl:apply-templates select="linkedeventvalue" /></premis:relatedEventIdentifierValue>
			</premis:relatedEventIdentifier>
		</premis:relationship>
		</xsl:when>
		<xsl:otherwise>
		<premis:linkingEventIdentifier>
			<premis:linkingEventIdentifierType>UUID</premis:linkingEventIdentifierType>
			<premis:linkingEventIdentifierValue><xsl:apply-templates select="//data/event/eventid" /></premis:linkingEventIdentifierValue>
		</premis:linkingEventIdentifier>
		</xsl:otherwise>
		</xsl:choose>
	</premis:object>
</xsl:template>

<xsl:template match="agent">
	<premis:agent>
  		<premis:agentIdentifier>
	    		<premis:agentIdentifierType>local</premis:agentIdentifierType>
	      		<premis:agentIdentifierValue><xsl:apply-templates select="agentname" /></premis:agentIdentifierValue>
	    	</premis:agentIdentifier>
	</premis:agent>
</xsl:template>

<xsl:template match="event">
	<premis:event>
		<premis:eventIdentifier>
			<premis:eventIdentifierType>UUID</premis:eventIdentifierType>
			<premis:eventIdentifierValue><xsl:apply-templates select="eventid"/></premis:eventIdentifierValue>
	    	</premis:eventIdentifier>
		<premis:eventType>imaging</premis:eventType>
		<premis:eventDateTime><xsl:apply-templates select="eventdate"/></premis:eventDateTime>
		<premis:eventDetailInformation>
			<premis:eventDetail><xsl:apply-templates select="eventdetail"/></premis:eventDetail>
		</premis:eventDetailInformation>
		<premis:eventOutcomeInformation>
			<premis:eventOutcome><xsl:apply-templates select="eventoutcome"/></premis:eventOutcome>
			<premis:eventOutcomeDetail>
				<premis:eventOutcomeDetailNote><xsl:apply-templates select="eventoutcomedetail"/></premis:eventOutcomeDetailNote>
			</premis:eventOutcomeDetail>
		</premis:eventOutcomeInformation>
	<xsl:for-each select="/data/agent">
		<premis:linkingAgentIdentifier>
			<premis:linkingAgentIdentifierType>local</premis:linkingAgentIdentifierType>
			<premis:linkingAgentIdentifierValue><xsl:value-of select="agentname" /></premis:linkingAgentIdentifierValue>
			<premis:linkingAgentRole><xsl:value-of select="agentrole" /></premis:linkingAgentRole>
	    	</premis:linkingAgentIdentifier>
	    </xsl:for-each>
    </premis:event>
</xsl:template>

</xsl:stylesheet>
