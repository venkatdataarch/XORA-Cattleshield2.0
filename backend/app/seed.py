"""
Seed script to populate form schemas and a default vet user.

Run with: python -m app.seed
"""
import asyncio
from sqlalchemy import select
from .database import async_session, create_tables
from .models.form_schema import FormSchema
from .models.user import User
from .utils.security import hash_password


FORM_SCHEMAS = [
    {
        "form_type": "proposal",
        "version": "1.0",
        "title": "Insurance Proposal Form",
        "animal_types": ["cow", "buffalo", "mule", "horse", "donkey"],
        "schema_json": {
            "id": "proposal_v1",
            "formType": "proposal",
            "version": "1.0",
            "title": "Insurance Proposal Form",
            "animalTypes": ["cow", "buffalo", "mule", "horse", "donkey"],
            "sections": [
                {
                    "id": "owner_details",
                    "title": "Owner Details",
                    "fields": [
                        {"key": "owner_name", "label": "Owner Name", "type": "text", "required": True},
                        {"key": "father_husband_name", "label": "Father/Husband Name", "type": "text", "required": True},
                        {"key": "address", "label": "Address", "type": "textarea", "required": True},
                        {"key": "village", "label": "Village", "type": "text", "required": True},
                        {"key": "district", "label": "District", "type": "text", "required": True},
                        {"key": "state", "label": "State", "type": "text", "required": True},
                        {"key": "pin_code", "label": "PIN Code", "type": "text", "required": True},
                        {"key": "phone", "label": "Phone Number", "type": "text", "required": True},
                        {"key": "occupation", "label": "Occupation", "type": "dropdown", "required": True, "options": ["Farmer", "Dairy Farmer", "Livestock Trader", "Other"]},
                    ],
                },
                {
                    "id": "animal_details",
                    "title": "Animal Details",
                    "fields": [
                        {"key": "animal_type", "label": "Animal Type", "type": "dropdown", "required": True, "options": ["Cow", "Buffalo", "Mule", "Horse", "Donkey"]},
                        {"key": "breed", "label": "Breed", "type": "text", "required": True},
                        {"key": "sex", "label": "Sex", "type": "radio", "required": True, "options": ["Male", "Female"]},
                        {"key": "sex_condition", "label": "Condition (if Female)", "type": "dropdown", "required": False, "options": ["Pregnant", "Calf at Foot", "Freshly Calved", "Heifer"], "showWhen": {"field": "sex", "operator": "value", "value": "Female"}},
                        {"key": "age_years", "label": "Age (Years)", "type": "number", "required": True, "validation": {"min": 0, "max": 25}},
                        {"key": "color", "label": "Color", "type": "text", "required": True},
                        {"key": "identification_marks", "label": "Distinguishing Marks", "type": "textarea", "required": False},
                        {"key": "tag_number", "label": "Ear Tag Number", "type": "text", "required": False},
                        {"key": "milk_yield", "label": "Milk Yield (Litres/day)", "type": "number", "required": False, "showWhen": {"field": "sex", "operator": "value", "value": "Female"}},
                    ],
                },
                {
                    "id": "insurance_details",
                    "title": "Insurance Details",
                    "fields": [
                        {"key": "sum_insured", "label": "Sum Insured (₹)", "type": "currency", "required": True},
                        {"key": "market_value", "label": "Market Value (₹)", "type": "currency", "required": True},
                        {"key": "insurance_period", "label": "Insurance Period", "type": "dropdown", "required": True, "options": ["1 Year", "2 Years", "3 Years"]},
                        {"key": "purpose_of_animal", "label": "Purpose of Animal", "type": "dropdown", "required": True, "options": ["Milching", "Breeding", "Draught", "Agriculture", "Transport"]},
                        {"key": "purchase_date", "label": "Date of Purchase", "type": "date", "required": False},
                        {"key": "purchase_price", "label": "Purchase Price (₹)", "type": "currency", "required": False},
                    ],
                },
                {
                    "id": "farm_details",
                    "title": "Farm & Shed Details",
                    "fields": [
                        {"key": "farm_location", "label": "Farm Location", "type": "text", "required": True},
                        {"key": "shed_type", "label": "Type of Shed", "type": "dropdown", "required": True, "options": ["Pucca", "Semi-Pucca", "Kutcha", "Open"]},
                        {"key": "vet_available", "label": "Veterinary Service Available?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                        {"key": "nearest_vet_distance", "label": "Distance to Nearest Vet (km)", "type": "number", "required": False},
                    ],
                },
                {
                    "id": "history",
                    "title": "Insurance & Loss History",
                    "fields": [
                        {"key": "previous_insurance", "label": "Previous Insurance?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                        {"key": "previous_policy_number", "label": "Previous Policy Number", "type": "text", "required": False, "showWhen": {"field": "previous_insurance", "operator": "value", "value": "Yes"}},
                        {"key": "past_animal_loss", "label": "Past Animal Loss?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                        {"key": "loss_details", "label": "Loss Details", "type": "textarea", "required": False, "showWhen": {"field": "past_animal_loss", "operator": "value", "value": "Yes"}},
                        {"key": "previous_claims", "label": "Previous Claims Filed?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                    ],
                },
                {
                    "id": "bank_details",
                    "title": "Ownership & Bank Details",
                    "fields": [
                        {"key": "ownership_type", "label": "Ownership Type", "type": "dropdown", "required": True, "options": ["Self-owned", "Financed/Bank Loan", "Leased"]},
                        {"key": "bank_name", "label": "Bank Name", "type": "text", "required": False, "showWhen": {"field": "ownership_type", "operator": "value", "value": "Financed/Bank Loan"}},
                        {"key": "loan_account", "label": "Loan Account Number", "type": "text", "required": False, "showWhen": {"field": "ownership_type", "operator": "value", "value": "Financed/Bank Loan"}},
                    ],
                },
            ],
        },
    },
    {
        "form_type": "claim_death",
        "version": "1.0",
        "title": "Claim Form - Death",
        "animal_types": ["cow", "buffalo", "mule", "horse", "donkey"],
        "schema_json": {
            "id": "claim_death_v1",
            "formType": "claim_death",
            "version": "1.0",
            "title": "Insurance Claim Form - Death",
            "animalTypes": ["cow", "buffalo", "mule", "horse", "donkey"],
            "sections": [
                {
                    "id": "policy_info",
                    "title": "Policy Information",
                    "fields": [
                        {"key": "policy_number", "label": "Policy Number", "type": "text", "required": True, "readOnly": True},
                        {"key": "claim_number", "label": "Claim Number", "type": "text", "required": False, "readOnly": True},
                    ],
                },
                {
                    "id": "incident_details",
                    "title": "Incident Details",
                    "fields": [
                        {"key": "date_animal_ill", "label": "When did animal become ill?", "type": "date", "required": True},
                        {"key": "vet_notification_date", "label": "Date vet was notified", "type": "date", "required": True},
                        {"key": "first_vet_visit", "label": "Date of first vet visit", "type": "date", "required": True},
                        {"key": "cause_of_death", "label": "Cause of Death", "type": "dropdown", "required": True, "options": ["Disease", "Accident", "Operation Complications", "Natural Causes", "Unknown"]},
                        {"key": "disease_name", "label": "Name of Disease", "type": "text", "required": False, "showWhen": {"field": "cause_of_death", "operator": "value", "value": "Disease"}},
                        {"key": "place_of_death", "label": "Place of Death", "type": "text", "required": True},
                        {"key": "date_of_death", "label": "Date of Death", "type": "date", "required": True},
                        {"key": "time_of_death", "label": "Time of Death", "type": "text", "required": False},
                    ],
                },
                {
                    "id": "animal_usage",
                    "title": "Animal Usage & Breeding",
                    "fields": [
                        {"key": "last_usage", "label": "Last Usage Purpose", "type": "dropdown", "required": True, "options": ["Milching", "Breeding", "Draught", "Agriculture", "Transport", "None"]},
                        {"key": "breeding_details", "label": "Breeding Details", "type": "textarea", "required": False},
                        {"key": "pregnancy_status", "label": "Was animal pregnant?", "type": "radio", "required": False, "options": ["Yes", "No", "N/A"]},
                    ],
                },
                {
                    "id": "claim_amount",
                    "title": "Claim Details",
                    "fields": [
                        {"key": "claim_amount", "label": "Claim Amount (₹)", "type": "currency", "required": True},
                        {"key": "other_insurance", "label": "Other Insurance on this animal?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                        {"key": "other_insurance_details", "label": "Other Insurance Details", "type": "textarea", "required": False, "showWhen": {"field": "other_insurance", "operator": "value", "value": "Yes"}},
                    ],
                },
            ],
        },
    },
    {
        "form_type": "claim_injury",
        "version": "1.0",
        "title": "Claim Form - Injury/Disease",
        "animal_types": ["cow", "buffalo", "mule", "horse", "donkey"],
        "schema_json": {
            "id": "claim_injury_v1",
            "formType": "claim_injury",
            "version": "1.0",
            "title": "Insurance Claim Form - Injury/Disease",
            "animalTypes": ["cow", "buffalo", "mule", "horse", "donkey"],
            "sections": [
                {
                    "id": "policy_info",
                    "title": "Policy Information",
                    "fields": [
                        {"key": "policy_number", "label": "Policy Number", "type": "text", "required": True, "readOnly": True},
                    ],
                },
                {
                    "id": "injury_details",
                    "title": "Injury/Disease Details",
                    "fields": [
                        {"key": "type", "label": "Type", "type": "radio", "required": True, "options": ["Injury", "Disease"]},
                        {"key": "date_noticed", "label": "Date Injury/Disease Noticed", "type": "date", "required": True},
                        {"key": "description", "label": "Description of Injury/Disease", "type": "textarea", "required": True},
                        {"key": "body_part_affected", "label": "Body Part Affected", "type": "text", "required": True},
                        {"key": "severity", "label": "Severity", "type": "dropdown", "required": True, "options": ["Mild", "Moderate", "Severe", "Critical"]},
                    ],
                },
                {
                    "id": "treatment",
                    "title": "Treatment Details",
                    "fields": [
                        {"key": "treatment_given", "label": "Treatment Given", "type": "textarea", "required": True},
                        {"key": "vet_name", "label": "Treating Veterinarian", "type": "text", "required": True},
                        {"key": "treatment_cost", "label": "Treatment Cost (₹)", "type": "currency", "required": True},
                        {"key": "claim_amount", "label": "Claim Amount (₹)", "type": "currency", "required": True},
                    ],
                },
            ],
        },
    },
    {
        "form_type": "vet_cert_proposal",
        "version": "1.0",
        "title": "Veterinary Certificate - Proposal",
        "animal_types": ["cow", "buffalo", "mule", "horse", "donkey"],
        "schema_json": {
            "id": "vet_cert_proposal_v1",
            "formType": "vet_cert_proposal",
            "version": "1.0",
            "title": "Veterinary Certificate for Proposal",
            "animalTypes": ["cow", "buffalo", "mule", "horse", "donkey"],
            "sections": [
                {
                    "id": "vet_info",
                    "title": "Veterinarian Information",
                    "fields": [
                        {"key": "vet_name", "label": "Veterinarian Name", "type": "text", "required": True},
                        {"key": "vet_qualification", "label": "Qualification", "type": "text", "required": True},
                        {"key": "vet_reg_number", "label": "Registration Number", "type": "text", "required": True},
                    ],
                },
                {
                    "id": "examination",
                    "title": "Animal Examination",
                    "fields": [
                        {"key": "examination_date", "label": "Date of Examination", "type": "date", "required": True},
                        {"key": "general_condition", "label": "General Health Condition", "type": "dropdown", "required": True, "options": ["Excellent", "Good", "Fair", "Poor"]},
                        {"key": "body_temp", "label": "Body Temperature (°F)", "type": "number", "required": True},
                        {"key": "heart_rate", "label": "Heart Rate (bpm)", "type": "number", "required": False},
                        {"key": "respiratory_rate", "label": "Respiratory Rate", "type": "number", "required": False},
                        {"key": "identity_confirmed", "label": "Animal Identity Confirmed?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                        {"key": "identity_method", "label": "Identification Method", "type": "dropdown", "required": True, "options": ["Ear Tag", "Muzzle Print", "Brand Mark", "Microchip", "Physical Description"]},
                    ],
                },
                {
                    "id": "health_history",
                    "title": "Health History",
                    "fields": [
                        {"key": "vaccination_status", "label": "Vaccination Status", "type": "dropdown", "required": True, "options": ["Up to date", "Partially vaccinated", "Not vaccinated", "Unknown"]},
                        {"key": "past_diseases", "label": "Past Diseases/Treatments", "type": "textarea", "required": False},
                        {"key": "current_medication", "label": "Current Medication", "type": "textarea", "required": False},
                        {"key": "fit_for_insurance", "label": "Fit for Insurance?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                        {"key": "remarks", "label": "Remarks", "type": "textarea", "required": False},
                    ],
                },
                {
                    "id": "declaration",
                    "title": "Declaration",
                    "fields": [
                        {"key": "declaration_confirmed", "label": "I certify the above information is true", "type": "checkbox", "required": True},
                    ],
                },
            ],
        },
    },
    {
        "form_type": "vet_cert_death",
        "version": "1.0",
        "title": "Veterinary Certificate - Death",
        "animal_types": ["cow", "buffalo", "mule", "horse", "donkey"],
        "schema_json": {
            "id": "vet_cert_death_v1",
            "formType": "vet_cert_death",
            "version": "1.0",
            "title": "Veterinary Certificate for Death Claim",
            "animalTypes": ["cow", "buffalo", "mule", "horse", "donkey"],
            "sections": [
                {
                    "id": "vet_info",
                    "title": "Veterinarian Information",
                    "fields": [
                        {"key": "vet_name", "label": "Veterinarian Name", "type": "text", "required": True},
                        {"key": "vet_qualification", "label": "Qualification", "type": "text", "required": True},
                        {"key": "vet_reg_number", "label": "Registration Number", "type": "text", "required": True},
                    ],
                },
                {
                    "id": "treatment_history",
                    "title": "Treatment History",
                    "fields": [
                        {"key": "first_visit_date", "label": "Date of First Visit", "type": "date", "required": True},
                        {"key": "symptoms_observed", "label": "Symptoms Observed", "type": "textarea", "required": True},
                        {"key": "diagnosis", "label": "Diagnosis", "type": "text", "required": True},
                        {"key": "treatment_given", "label": "Treatment Given", "type": "textarea", "required": True},
                        {"key": "number_of_visits", "label": "Number of Visits", "type": "number", "required": True},
                    ],
                },
                {
                    "id": "post_mortem",
                    "title": "Post-Mortem Details",
                    "fields": [
                        {"key": "post_mortem_conducted", "label": "Post-Mortem Conducted?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                        {"key": "post_mortem_date", "label": "Post-Mortem Date", "type": "date", "required": False, "showWhen": {"field": "post_mortem_conducted", "operator": "value", "value": "Yes"}},
                        {"key": "post_mortem_findings", "label": "Post-Mortem Findings", "type": "textarea", "required": False, "showWhen": {"field": "post_mortem_conducted", "operator": "value", "value": "Yes"}},
                        {"key": "cause_of_death", "label": "Cause of Death", "type": "text", "required": True},
                        {"key": "death_natural", "label": "Was death from natural causes?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                    ],
                },
                {
                    "id": "identity_verification",
                    "title": "Animal Identity Verification",
                    "fields": [
                        {"key": "identity_confirmed", "label": "Animal Identity Confirmed?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                        {"key": "identity_method", "label": "Identification Method Used", "type": "dropdown", "required": True, "options": ["Ear Tag", "Muzzle Print", "Brand Mark", "Physical Description"]},
                        {"key": "care_adequate", "label": "Was care and treatment adequate?", "type": "radio", "required": True, "options": ["Yes", "No"]},
                        {"key": "care_remarks", "label": "Care & Treatment Remarks", "type": "textarea", "required": False},
                    ],
                },
                {
                    "id": "declaration",
                    "title": "Declaration",
                    "fields": [
                        {"key": "declaration_confirmed", "label": "I certify all above information is true and correct", "type": "checkbox", "required": True},
                    ],
                },
            ],
        },
    },
]


async def seed():
    await create_tables()

    async with async_session() as session:
        # Seed form schemas
        for schema_data in FORM_SCHEMAS:
            result = await session.execute(
                select(FormSchema).where(FormSchema.form_type == schema_data["form_type"])
            )
            existing = result.scalar_one_or_none()
            if not existing:
                schema = FormSchema(
                    form_type=schema_data["form_type"],
                    version=schema_data["version"],
                    title=schema_data["title"],
                    schema_json=schema_data["schema_json"],
                    animal_types=schema_data["animal_types"],
                )
                session.add(schema)
                print(f"  ✓ Seeded form schema: {schema_data['form_type']}")
            else:
                print(f"  - Form schema already exists: {schema_data['form_type']}")

        # Seed a default vet user
        vet_result = await session.execute(
            select(User).where(User.phone == "vet001")
        )
        if not vet_result.scalar_one_or_none():
            vet = User(
                name="Dr. Rajesh Kumar",
                phone="vet001",
                role="vet",
                qualification="BVSc & AH",
                reg_number="VET-2024-001",
                password_hash=hash_password("vet123"),
                district="Hyderabad",
                state="Telangana",
            )
            session.add(vet)
            print("  ✓ Seeded default vet: vet001 / vet123")
        else:
            print("  - Default vet already exists")

        await session.commit()
        print("\n✅ Seed completed successfully!")


if __name__ == "__main__":
    asyncio.run(seed())
