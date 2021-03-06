/*
 * Copyright 2015 Comcast Cable Communications Management, LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.comcast.cdn.traffic_control.traffic_router.core.loc;

import java.util.HashMap;
import java.util.Map;

import org.apache.commons.lang3.builder.EqualsBuilder;
import org.apache.commons.lang3.builder.HashCodeBuilder;
import com.maxmind.geoip2.model.CityResponse;

public class Geolocation {
	private static final double MEAN_EARTH_RADIUS = 6371.0f;

	private final double latitude;
	private final double longitude;

	private String postalCode;

	private String city;

	private String countryCode;

	private String countryName;

	/**
	 * Creates an immutable {@link Geolocation}.
	 * 
	 * @param latitude
	 *            in decimal degrees
	 * @param longitude
	 *            in decimal degrees
	 */
	public Geolocation(final double latitude, final double longitude) {
		this.latitude = latitude;
		this.longitude = longitude;
	}

	public Geolocation(final CityResponse response) {
		// we will check getLocation from caller because these fields are final
		this.latitude = response.getLocation().getLatitude();
		this.longitude = response.getLocation().getLongitude();

		if (response.getPostal() != null) {
			this.postalCode = response.getPostal().getCode();
		}

		if (response.getCity() != null) {
			this.city = response.getCity().getName();
		}

		if (response.getCountry() != null) {
			this.countryCode = response.getCountry().getIsoCode();
			this.countryName = response.getCountry().getName();
		}
	}

	public Map<String,String> getProperties() {
		final Map<String,String> map = new HashMap<String,String>();
		map.put("latitude", Double.toString(latitude));
		map.put("longitude", Double.toString(longitude));
		map.put("postalCode", postalCode);
		map.put("city", city);
		map.put("countryCode", countryCode);
		map.put("countryName", countryName);
		return map;
	}

	@Override
	public boolean equals(final Object obj) {
		if (this == obj) {
			return true;
		} else if (obj instanceof Geolocation) {
			final Geolocation rhs = (Geolocation) obj;
			return new EqualsBuilder()
					.append(getLatitude(), rhs.getLatitude())
					.append(getLongitude(), rhs.getLongitude())
					.isEquals();
		} else {
			return false;
		}
	}

	/**
	 * Returns the great circle distance in kilometers between this {@link Geolocation} and the
	 * specified location
	 * 
	 * @param other
	 * @return the great circle distance in km
	 */
	public double getDistanceFrom(final Geolocation other) {
		if (other != null) {
			final double dLat = Math.toRadians(getLatitude() - other.getLatitude());
			final double dLon = Math.toRadians(getLongitude() - other.getLongitude());
			final double a = (Math.sin(dLat / 2) * Math.sin(dLat / 2))
					+ (Math.cos(Math.toRadians(getLatitude())) * Math.cos(Math.toRadians(other.getLatitude()))
							* Math.sin(dLon / 2) * Math.sin(dLon / 2));
			final double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
			return MEAN_EARTH_RADIUS * c;
		} else {
			return Double.POSITIVE_INFINITY;
		}
	}

	/**
	 * Retrieves the latitude in decimal degrees
	 * 
	 * @return latitude in decimal degrees
	 */
	public double getLatitude() {
		return latitude;
	}

	/**
	 * Retrieves the longitude in decimal degrees
	 * 
	 * @return longitude in decimal degrees
	 */
	public double getLongitude() {
		return longitude;
	}

	@Override
	public int hashCode() {
		return new HashCodeBuilder(1, 31)
		.append(getLatitude())
		.append(getLongitude())
		.toHashCode();
	}

	@Override
	public String toString() {
		return "Geolocation [latitude=" + latitude + ", longitude=" + longitude + "]";
	}

}
